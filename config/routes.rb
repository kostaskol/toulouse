Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :platform do
    root "home#show"
    resource :session, only: [:new, :create]
    # HTML forms cannot send DELETE, and method override stays off the API.
    post "logout", to: "sessions#destroy"

    resources :tenants, only: :index do
      resources :api_keys, only: [:index, :show, :create] do
        post :revoke, on: :member
      end
    end
  end

  namespace :v1 do
    namespace :storefront do
      resource :session, only: [:create, :show, :destroy]
    end
  end

  namespace :admin do
    resource :session, only: [:create, :show, :destroy]
    resource :password_reset, only: [:create, :update]
    resources :staff, only: :create
  end
end
