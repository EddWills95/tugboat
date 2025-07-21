json.extract! project, :id, :name, :docker_image, :port, :status, :created_at, :updated_at, :subdomain
json.url project_url(project, format: :json)
