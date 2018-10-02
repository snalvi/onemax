require "sinatra"
require "sinatra/activerecord"
require 'sinatra/cross_origin'
require_relative 'models/nomination'
require_relative 'models/user'
require_relative 'models/dua_vote'
require "json"
require "carrierwave_direct"
require "carrierwave/orm/activerecord"
require "carrierwave/storage/fog"
require "fog"
# require "refile"
# require "refile/s3"
require "aws-sdk"
require "base64"
require "data_uri"


class App < Sinatra::Base

	PAGED_RESULTS = 18

	configure do
		enable :cross_origin
	end

	before do
		content_type 'application/json'
		response.headers['Access-Control-Allow-Origin'] = '*'
	end

	def search_results(search_params)
		matching_nominees = []

		Nomination.where(status: 'approved').order('created_at DESC').each do |nomination|
			search_params.split(' ').each do |search_query|

				unless nomination.tags.nil? 
					matching_nominees << nomination if nomination.tags =~ /#{search_query}/i
				end

				unless nomination.country.nil? 
					matching_nominees << nomination if nomination.country =~ /#{search_query}/i
				end

				unless nomination.province.nil? 
					matching_nominees << nomination if nomination.province =~ /#{search_query}/i
				end

				unless nomination.name.nil?
					matching_nominees << nomination if nomination.name =~ /#{search_query}/i
				end
			end
		end

		matching_nominees.uniq
	end

	def filtered_nominees(filter_param, nominees)
		matching_nominees = []

		if nominees.nil? or nominees == []
			nominees = Nomination.where(status: 'approved').order('created_at DESC')
		end

		nominees.each do |nomination|
			unless nomination.country.nil?
				matching_nominees << nomination if nomination.country =~ /#{filter_param}/i
			end

			unless nomination.province.nil?
				matching_nominees << nomination if nomination.province =~ /#{filter_param}/i
			end
		end

		matching_nominees
	end

	def filter_results(filter_params, nominees)
		matching_nominees = nominees

		if nominees.nil? or nominees == []
			matching_nominees = Nomination.where(status: 'approved').order('created_at DESC')
		end

		filter_params.split(' ').each do |filter_param|
			matching_nominees = filtered_nominees(filter_param, matching_nominees)
		end

		matching_nominees.uniq
	end

	def access_id_for_user(user_id)
		user = User.find_by(id: user_id)
		if user.nil?
			return nil
		end

		return user.access_id
	end

	options "*" do
		response.headers["Access-Control-Allow-Methods"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"
		response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
		200
	end

	get "/" do
	  "Hello world!"
	end

	get "/submitted_nominations" do
		userId = env['HTTP_USERID']
		page = params[:page].to_i

		if userId.nil? or userId.empty?
			status 500
			body "User Id must be provided in header"
			return
		end

		if userId != "105364027055888" and userId != "111223425403387795098"
			status 403
			body "Unauthorized user"
			return
		end

		nominations = []

		if page.zero?
			page = 1
		end

		nominations = Nomination.where(status: 'submitted').order(duas: :desc).page(page)

		{'nextPage': page + 1, nominations: nominations}.to_json
	end

	get "/nominations" do
		nominations = Nomination.order(duas: :desc)
		nominations.to_json
	end

	get "/paged_nominations" do
		page = params[:page].to_i

		sort_by_param = params[:sort_by]
		type_param = params[:type]

		type = 'created_at'
		unless (type_param.nil? or type_param.empty?)
			if type_param.downcase == "duas" or type_param.downcase == "created_at"
				type = type_param.downcase
			else
				status 500
				body "Type must be `duas` or `created_at`, provided #{type_param}"
				return
			end
		end

		sort_by = 'DESC'
		unless (sort_by_param.nil? or sort_by_param.empty?)
			if sort_by_param.downcase == "asc" or sort_by_param.downcase == "desc"
				sort_by = sort_by_param.upcase
			else
				status 500
				body "Sort By supports asc or desc, provided: #{sort_by_param}"
				return
			end
		end

		nominations = []

		if page.zero?
			page = 1
		end

		puts "=== type: #{type}, sort_by: #{sort_by}"

		nominations = Nomination.where(status: 'approved').order(type + ' ' + sort_by).page(page)
		nominations.map{ |nomination| nomination.user_id = access_id_for_user(nomination.user_id) }

		{'nextPage': page + 1, nominations: nominations}.to_json
	end

	post "/nominations" do
		name = params[:name]
		description = params[:description]
		tags = params[:tags] || ''
		country = params[:country]
		province = params[:province]
		image = params[:file] || nil
		userId = params[:userID] || ''
		userName = params[:userName] || ''

		user = nil
		if userId.nil? or userId.empty?
			status 401
			body "user id not specified"
			return
		else
			user = User.find_by(access_id: userId)
			if user.nil?
				user = User.create!({access_id: userId})
			end
		end

		if userName.nil? or userName.empty?
			status 500
			body "User name not specified"
			return
		end

		user.user_name = userName
		user.save

		nomination = Nomination.create({name: name,
			description: description,
			tags: tags,
			country: country,
			province: province,
			duas: 1,
			user_id: user.id
		})

		if nomination.valid?
			if image != nil and image != ""
				uri = URI::Data.new(image)

				filename = nomination.id.to_s + "_image_" + Time.now.strftime('%Y%b%d_%H:%M:%S') + '.png'
				s3 = Aws::S3::Client.new(
				  access_key_id: ENV.fetch('s3_access_key_id'),
				  secret_access_key: ENV.fetch('s3_secret_access_key'),
				  region: ENV.fetch('s3_region'),
				)
				response = s3.put_object(bucket: ENV.fetch('s3_bucket'), key: filename, body: uri.data, acl: "public-read")

				url = "https://s3.amazonaws.com/" + ENV.fetch('s3_bucket') + "/" + filename

				nomination.image = url
			end

			nomination.save

			status 201
			body "nomination saved #{nomination.id}; url: #{url}"
		else
			status 500
			body nomination.errors.messages.to_s.to_json
		end
	end

	put "/nominations/:id" do
		name = params[:name]
		description = params[:description]
		tags = params[:tags] || ''
		country = params[:country]
		province = params[:province]
		image = params[:file] || ''
		userId = params[:userID] || ''
		nominationId = params[:id].to_i

		user = nil
		if userId.nil? or userId.empty?
			puts "user id is nil"
			status 401
			body "User id not specified"
			return
		else
			user = User.find_by(access_id: userId)
			if user.nil?
				status 404
				body "User with id #{userId} not found"
				return
			end
		end

		nomination = Nomination.find_by(id: nominationId)
		if nomination.nil?
			status 404
			body "Nomination with id #{nominationId} not found"
			return
		end

		if nomination.user_id != user.id
			status 403
			body "User #{userId} does not have permissions to edit this nominee"
			return
		end

		# image provided
		if image != nil and image != "" and image != "REMOVED"
			uri = URI::Data.new(image)

			filename = nomination.id.to_s + "_image_" + Time.now.strftime('%Y%b%d_%H:%M:%S') + '.png'
			s3 = Aws::S3::Client.new(
			  access_key_id: ENV.fetch('s3_access_key_id'),
			  secret_access_key: ENV.fetch('s3_secret_access_key'),
			  region: ENV.fetch('s3_region'),
			)
			response = s3.put_object(bucket: ENV.fetch('s3_bucket'), key: filename, body: uri.data, acl: "public-read")

			image = "https://s3.amazonaws.com/" + ENV.fetch('s3_bucket') + "/" + filename
		
			nomination.update(name: name, description: description, tags: tags, country: country, province: province, image: image)
		
		# image set to be removed
		elsif image == "REMOVED"

			nomination.update(name: name, description: description, tags: tags, country: country, province: province, image: '')

		# image sent as empty; do not update image entry
		else
			
			nomination.update(name: name, description: description, tags: tags, country: country, province: province)
		end

		if nomination.valid?
			nomination.save

			status 204
			body "Successfully updated nomination #{nominationId}"
		else
			status 500
			body nomination.errors.messages.to_s.to_json
		end
	end

	delete "/nominations/:id" do
		id = params[:id].to_i
		userId = params[:userId]

		if id.nil? or id.zero?
			status 500
			body 'ID of nominee to delete not specified: #{id}'
			return
		end

		nomination = Nomination.find_by(id: id)
		if nomination.nil? 
			status 404
			body "Unable to find nomination with id #{id}"
			return
		end

		user = User.find_by(access_id: userId)
		if user.nil?
			status 404
			body "Unable to find user with id: #{userId}"
			return
		end

		if nomination.user_id != user.id
			status 403
			body "User #{userId} does not have permissions to delete this nominee"
			return
		end

		nomination.destroy

		if nomination.destroyed?
			status 200
			body 'Successfully deleted'
		else
			status 500
			body "Error deleting resource #{nomination.errors.messages.to_s.to_json}"
		end
	end

	get "/search" do
		search_params = params[:tags]
		page = params[:page].to_i

		if search_params.nil? or search_params == ""
			status 500
			body "No search params provided"
		end

		if page <= 1
			page = 1
		end

		matching_nominees = search_results(search_params)

		paged_nominees = Kaminari.paginate_array(matching_nominees).page(page).per(PAGED_RESULTS)
		paged_nominees.map{ |nomination| nomination.user_id = access_id_for_user(nomination.user_id) }

		unless paged_nominees.nil?
			if paged_nominees.size >= PAGED_RESULTS
				page += 1
			end
		else
			paged_nominees = []
		end

		{'nextPage': page, nominations: paged_nominees}.to_json
	end

	get "/filter" do
		search_params = params[:search]
		filter_params = params[:filter]
		page = params[:page].to_i


		if filter_params.nil? or filter_params == ""
			status 500
			body "No filter params provided"
			return
		end

		if page <= 1
			page = 1
		end

		matching_nominees = []
		if !search_params.nil? and search_params != ""
			matching_nominees = search_results(search_params)
		end

		filtered_nominations = filter_results(filter_params, matching_nominees)

		# filtered_nominations = filtered_nominations.uniq.sort_by{ |nom| nom.duas }.reverse
		paged_nominees = Kaminari.paginate_array(filtered_nominations).page(page).per(PAGED_RESULTS)

		unless paged_nominees.nil?
			if paged_nominees.size >= PAGED_RESULTS
				page += 1
			end
		else
			paged_nominees = []
		end

		{'nextPage': page, nominations: paged_nominees}.to_json
	end

	get "/duaNames/:nominee_id" do
		nomination_id = params[:nominee_id]

		if nomination_id.nil? or nomination_id.empty?
			status 500
			body "Nominee Id is nil or empty"
			return
		end

		nomination = Nomination.find_by(id: nomination_id)
		if nomination.nil?
			status 404
			body "Nominee with id #{nomination_id} not found"
			return
		end

		names = []
		dua_votes = DuaVote.where(nomination_id: nomination_id)

		unless dua_votes.nil? or dua_votes.empty?
			dua_votes.each do |dua_vote|
				user = User.find_by(id: dua_vote.user_id)
				unless user.nil?
					names << user.user_name unless user.user_name.empty?
				end
			end
		end

		puts "=== users for dua names: #{names}"

		{names: names}.to_json
	end

	post "/dua" do
		nomination_id = params[:nominee_id].to_i
		nominated_by = params[:nominated_by]
		user_name = params[:userName]

		if nominated_by.nil? or nominated_by.empty? or nomination_id.nil?
			status 500
			body "Nominations Id or Nominated By Access Id is nil or empty"
			return
		end

		if user_name.nil? or user_name.empty?
			status 500
			body "User name should not be nil"
			return
		end

		user = User.find_by(access_id: nominated_by)
		if user.nil?
			user = User.create!({access_id: nominated_by, user_name: user_name})
		end

		nomination = Nomination.find_by(id: nomination_id)
		if nomination.nil?
			status 500
			body "Nominee Id was not found: #{nomination_id}"
		end

		previous_vote = DuaVote.find_by(user: user, nomination: nomination)

 		if previous_vote.nil?
			DuaVote.create!({user: user, nomination: nomination})
			duas = nomination.duas
			nomination.update(duas: duas+1)
			{id: nomination.id, duas: nomination.duas}.to_json
		else
			previous_vote.destroy
			duas = nomination.duas
			nomination.update(duas: duas-1)
			{id: nomination.id, duas: nomination.duas}.to_json
		end
	end
end

