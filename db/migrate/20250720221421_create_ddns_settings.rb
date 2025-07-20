class CreateDdnsSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :ddns_settings, id: false do |t|
      t.string :primary_key, default: 'singleton', primary_key: true
      t.boolean :enabled, default: false
      t.string :base_domain
      t.string :aws_access_key_id
      t.string :aws_secret_access_key
      t.string :aws_region, default: 'us-east-1'
      t.string :route53_hosted_zone_id
      t.integer :update_interval, default: 300 # 5 minutes
      t.timestamp :last_update
      t.string :current_ip
      t.string :last_error
      t.timestamps
    end
  end
end
