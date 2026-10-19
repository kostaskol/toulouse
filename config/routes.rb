Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Public: <img> tags cannot send credentials. The signed ids are the only key.
  get "media/:signed_blob_id/:variation_key/*filename", to: "active_storage/representations/proxy#show", as: :media

  namespace :platform do
    root "home#show"
    resource :session, only: [:new, :create]
    # HTML forms cannot send DELETE, and method override stays off the API.
    post "logout", to: "sessions#destroy"

    resources :tenants, only: [:index, :show] do
      resources :api_keys, only: [:index, :show, :create] do
        post :revoke, on: :member
      end
      resources :handoffs, only: :create
      resources :impersonations, only: :create
    end
  end

  namespace :v1 do
    # The BFF matches session routes by exact path, so .json must not reach the same action.
    namespace :storefront, format: false do
      resource :session, only: [:create, :show, :destroy]
      resource :handoff, only: :create
      resource :signup, only: [:create, :update]
      resource :password_reset, only: [:create, :update]
      resources :products, only: [:index, :show], param: :slug
      resources :categories, only: :index, param: :slug do
        resources :products, only: :index, controller: "category_products"
      end
      # Any character but a slash, so a query with a dot is not cut short.
      get "search/:query", to: "searches#show", constraints: { query: %r{[^/]+} }
    end
  end

  namespace :admin do
    resource :session, only: [:create, :show, :destroy]
    resource :password_reset, only: [:create, :update]
    resources :staff, only: [:index, :create, :destroy]
    resource :invite, only: :update

    resources :brands, only: [:index, :create, :update, :destroy]
    resources :categories, only: [:index, :create, :update, :destroy]
    resources :specifications, only: [:index, :create, :update, :destroy]
    resources :products, only: [:index, :show, :create, :update] do
      resources :images, only: [:create, :update, :destroy] do
        put :order, on: :collection
      end
      resources :variants, only: [:create, :update] do
        resource :stock, only: :update
      end
    end
    resources :product_imports, only: [:index, :show, :create] do
      resources :entries, only: :index, controller: "product_import_entries"
    end
  end
end
