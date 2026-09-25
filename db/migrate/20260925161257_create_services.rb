class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.string :repository
      t.string :branch, null: false, default: "main"
      t.string :region, null: false
      t.string :size, null: false, default: "small"
      t.integer :replicas, null: false, default: 1
      t.boolean :autoscale, null: false, default: false
      t.string :health_check_path, null: false, default: "/up"
      t.text :environment
      t.text :notes
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :services, :name, unique: true
  end
end
