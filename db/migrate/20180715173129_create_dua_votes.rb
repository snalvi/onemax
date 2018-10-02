class CreateDuaVotes < ActiveRecord::Migration[5.2]
  def change
  	create_table :dua_votes do |t|
      t.belongs_to :nomination
      t.belongs_to :user
    end
  end
end
