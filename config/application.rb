require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Tracksys
   class Application < Rails::Application
      config.load_defaults 5.2

      config.autoload_paths += Dir[Rails.root.join('app', 'models', '{*/}')]

      # config.autoload_paths << Rails.root.join('app',"models", "metadata")
      # config.autoload_paths << Rails.root.join('app',"models", "equipment")
      # config.autoload_paths << Rails.root.join('app',"models", "controlled_vocabulary")
      # config.autoload_paths << Rails.root.join('app',"models", "digitization_workflow")

      # config.autoload_paths << Rails.root.join('app',"admin", "metadata")
      # config.autoload_paths << Rails.root.join('app',"admin", "digitization_workflow")
      # config.autoload_paths << Rails.root.join('app',"admin", "controlled_vocabulary")

      # Settings in config/environments/* take precedence over those specified here.
      # Application configuration should go into files in config/initializers
      # -- all .rb files in that directory are automatically loaded.

      # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
      # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
      config.time_zone = 'Eastern Time (US & Canada)'

      # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
      # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
      # config.i18n.default_locale = :de

      # # Do not swallow errors in after_commit/after_rollback callbacks.
      # config.active_record.raise_in_transactional_callbacks = true
   end
end
