Rails.application.routes.draw do
  # User Settings routes
  get "user_settings/edit", to: "user_settings#edit", as: :edit_user_settings
  patch "user_settings", to: "user_settings#update", as: :user_settings

  # DDNS Settings feature is on hold

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
  root "home#index"

  get "reverse_proxy", to: "reverse_proxy#index"
  post "reverse_proxy/reload", to: "reverse_proxy#reload", as: :reload_reverse_proxy
  post "reverse_proxy/start", to: "reverse_proxy#start", as: :start_reverse_proxy
  post "reverse_proxy/stop", to: "reverse_proxy#stop", as: :stop_reverse_proxy
  post "reverse_proxy/clean", to: "reverse_proxy#clean", as: :clean_reverse_proxy
end
