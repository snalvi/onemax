require 'kaminari'

class Nomination < ActiveRecord::Base
	paginates_per 18

	validates :name, presence: true
	validates :description, presence: true
	validates :country, presence: true

	# has_one :user
	has_many :dua_vote

	attr_accessor :access_id
end