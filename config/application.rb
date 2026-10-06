require_relative "boot"

require "rails"

# Action Mailbox is left out because its ingress routes take requests with no
# tenant.
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "action_cable/engine"
require "action_text/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Toulouse
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # The tenant admin session travels in a cookie.
    config.middleware.use ActionDispatch::Cookies

    # Holds platform admin's CSRF token. The API never loads a session, so it
    # never sets this cookie.
    config.session_store :cookie_store, key: "_platform_session", path: "/platform", same_site: :strict,
                                        secure: !Rails.env.local?
    config.middleware.use config.session_store, config.session_options

    config.x.admin_origin = ENV["ADMIN_ORIGIN"]

    # Blob and upload routes take requests with no tenant, and blobs carry no
    # tenant_id.
    config.active_storage.draw_routes = false

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end
