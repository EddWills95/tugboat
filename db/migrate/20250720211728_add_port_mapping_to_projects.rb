class AddPortMappingToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :internal_port, :integer
    add_column :projects, :external_port, :integer

    # Migrate existing port data
    reversible do |dir|
      dir.up do
        # Copy existing port values to external_port and set internal_port to same value
        execute "UPDATE projects SET external_port = port, internal_port = port WHERE port IS NOT NULL"
      end
    end
  end
end
