class CreateNominations < ActiveRecord::Migration[5.2]
  def change
  	create_table :nominations do |t|

      t.string :name, null: false
      t.string :description, null: false
      t.string :tags, default: ''
      t.string :country, null: false
      t.integer :duas, null: false
      t.string :status, default: 'submitted'
      t.string :province, null: false, default: ''
      t.string :image, null: false, default: ''

      t.timestamps
    end

    # add_index :name, unique: true
  end
end
