Rails.application.routes.draw do
  # DDNS Settings routes
  get "ddns_settings", to: "ddns_settings#index"
  patch "ddns_settings", to: "ddns_settings#update"
  post "ddns_settings/toggle_service", as: :toggle_service_ddns_settings
  post "ddns_settings/start_service", as: :start_service_ddns_settings
  post "ddns_settings/stop_service", as: :stop_service_ddns_settings
  post "ddns_settings/restart_service", as: :restart_service_ddns_settings

  resources :projects do
    member do
      post :deploy
      post :start
      post :stop
      get :logs
      get :refresh_logs
    end
  end
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "projects#index"
end
