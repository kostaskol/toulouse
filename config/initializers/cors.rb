# The tenant admin UI is the only browser client. Storefronts reach the API
# server to server through their BFF and need no CORS.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Read per request, so an unset origin admits nothing.
    origins { |source, _env| source.present? && source == Rails.configuration.x.admin_origin }

    resource "/admin/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      # The login form reads it to say how long an account stays locked.
      expose: ["Retry-After"],
      credentials: true
  end
end
