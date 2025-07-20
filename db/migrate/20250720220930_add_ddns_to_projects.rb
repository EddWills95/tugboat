class AddDdnsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :domain, :string
    add_column :projects, :ddns_enabled, :boolean, default: false
    add_column :projects, :ddns_provider, :string
    add_column :projects, :ddns_config, :json, default: {}
  end
end
