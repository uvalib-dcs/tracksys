ActiveAdmin.setup do |config|
  # View a list of all the elements you can override
  # https://github.com/gregbell/active_admin/blob/master/lib/active_admin/view_factory.rb
  #config.view_factory.register utility_navigation: HeaderUserInfo

  # == Site Title
  #
  # Set the title that is displayed on the main layout
  # for each of the active admin pages.
  #
  config.site_title = "Tracksys"

  # Set the link url for the title. For example, to take
  # users to your main site. Defaults to no link.
  #
  # config.site_title_link = "/"

  # Set an optional image to be displayed for the header
  # instead of a string (overrides :site_title)
  #
  # Note: Recommended image height is 21px to properly fit in the header
  #
  # config.site_title_image = "/images/logo.png"

  # == Default Namespace
  #
  # Set the default namespace each administration resource
  # will be added to.
  #
  # eg:
  #   config.default_namespace = :hello_world
  #
  # This will create resources in the HelloWorld module and
  # will namespace routes to /hello_world/*
  #
  # To set no namespace by default, use:
  #   config.default_namespace = false
  #
  # Default:
  config.default_namespace = :admin
  #
  # You can customize the settings for each namespace by using
  # a namespace block. For example, to change the site title
  # within a namespace:
  #
  #   config.namespace :admin do |admin|
  #     admin.site_title = "Custom Admin Title"
  #   end
  #
  config.namespace :admin do |admin|
    admin.site_title = "Tracksys #{TRACKSYS_VERSION}"
    admin.build_menu do |menu|
       menu.add label: 'Metadata', priority: 10
       menu.add label: 'Digitization', priority: 12 do |dw|
        dw.add :label => "Projects", :url => Settings.qa_viewer_url, priority: 1,  :html_options => { :target => :blank }
        dw.add :label => "Reports", :url => "#{Settings.reporting_url}/reports", priority: 3,  :html_options => { :target => :blank }
       end
       menu.add label: 'Miscellaneous', priority: 15 do |dw|
        dw.add :label => "Statistics", :url => Settings.reporting_url, priority: 16,  :html_options => { :target => :blank }
       end
    end
  end

  #   # In order to have multiple ActiveAdmin namespaces (i.e. /app/admin and /app/transcription), the ActiveAdmin initializer
  # # must load all paths containing namespaced ActiveAdmin assets.
  # #
  # # See https://groups.google.com/group/activeadmin/browse_thread/thread/799ab4350c848162 for more information.
  # config.load_paths = [File.expand_path('app/admin', Rails.root),
  #   File.expand_path('app/patron', Rails.root)]

  # This will ONLY change the title for the admin section. Other
  # namespaces will continue to use the main "site_title" configuration.

  # == User Authentication
  #
  # Active Admin will automatically call an authentication
  # method in a before filter of all controller actions to
  # ensure that there is a currently logged in admin user.
  #
  # This setting changes the method which Active Admin calls
  # within the controller.
  # config.authentication_method = :authenticate_admin_user!


  # == Current User
  #
  # Active Admin will associate actions with the current
  # user performing them.
  #
  # This setting changes the method which Active Admin calls
  # to return the currently logged in user.
  # config.current_user_method = :current_admin_user

  # Turn off Devise authentication; NetBadge is used instead. In dev mode all access granted
 config.authentication_method = false
 config.current_user_method   = :current_user
 config.before_action :authorize, :except => [ :access_denied ]

  # # Set language
  # config.before_action :set_admin_locale

  # == Logging Out
  #
  # Active Admin displays a logout link on each screen. These
  # settings configure the location and method used for the link.
  #
  # This setting changes the path where the link points to. If it's
  # a string, the strings is used as the path. If it's a Symbol, we
  # will call the method to return the path.
  #
  # Default:
  config.logout_link_path = false

  # This setting changes the http method used when rendering the
  # link. For example :get, :delete, :put, etc..
  #
  # Default:
  # config.logout_link_method = :get

  # == Root
  #
  # Set the action to call for the root path. You can set different
  # roots for each namespace.
  #
  # Default:
  # config.root_to = 'home#index'

  # == Admin Comments
  #
  # Admin comments allow you to add comments to any model for admin use.
  # Admin comments are enabled by default.
  #
  # Default:
  # config.allow_comments = true
  config.comments = false
  config.comments_menu = false
  #
  # You can turn them on and off for any given namespace by using a
  # namespace config block.
  #
  # Eg:
  #   config.namespace :without_comments do |without_comments|
  #     without_comments.allow_comments = false
  #   end


  # == Batch Actions
  #
  # Enable and disable Batch Actions
  #
  config.batch_actions = true


  # == Controller Filters
  #
  # You can add before, after and around filters to all of your
  # Active Admin resources from here.
  #
  # config.before_action :do_something_awesome


  # == CSV options
  #
  # Set the CSV builder separator (default is ",")
  # config.csv_column_separator = ','
end
