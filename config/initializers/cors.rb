# The tenant admin UI is the only browser client. Storefronts reach the API
# server to server through their BFF and need no CORS.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Read per request, so an unset origin admits nothing.
    origins { |source, _env| source.present? && source == Rails.configuration.x.admin_origin }

    resource "/v1/admin/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
