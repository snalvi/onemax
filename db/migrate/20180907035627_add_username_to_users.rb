class AddUsernameToUsers < ActiveRecord::Migration[5.2]
  def change
  	change_table :users do |t|
      t.string :user_name, null: false, default: ''
    end
  end
end

