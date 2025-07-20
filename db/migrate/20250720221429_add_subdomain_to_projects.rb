class AddSubdomainToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :subdomain, :string
    add_column :projects, :custom_domain, :string
    add_column :projects, :ssl_enabled, :boolean, default: true

    add_index :projects, :subdomain, unique: true
  end
end
