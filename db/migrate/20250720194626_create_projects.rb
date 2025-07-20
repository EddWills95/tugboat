class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name
      t.string :docker_image
      t.integer :port
      t.string :status

      t.timestamps
    end
  end
end
