class RemoveStatusFromProjects < ActiveRecord::Migration[8.0]
  def change
    remove_column :projects, :status, :string
  end
end
