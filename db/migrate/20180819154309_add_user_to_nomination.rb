class AddUserToNomination < ActiveRecord::Migration[5.2]
  def change
  	change_table :nominations do |t|
      t.belongs_to :user
    end
  end
end
