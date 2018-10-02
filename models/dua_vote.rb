class DuaVote < ActiveRecord::Base
	belongs_to :nomination	
	belongs_to :user
end