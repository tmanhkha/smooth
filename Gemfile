source 'https://rubygems.org'

# Core framework
gem 'rails', '~> 8.1.3'

# Database and web server
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'

# Assets and frontend
gem 'propshaft'
gem 'importmap-rails'
gem 'stimulus-rails'
gem 'tailwindcss-rails'
gem 'turbo-rails'

# API responses and media processing
gem 'jbuilder'
gem 'image_processing', '~> 1.2'

# Authentication and security
gem 'bcrypt', '~> 3.1'

# Rails infrastructure
gem 'solid_cache'
gem 'solid_cable'
gem 'solid_queue'

# Performance and platform support
gem 'tzinfo-data', platforms: %i[ windows jruby ]
gem 'bootsnap', require: false

# Deployment
gem 'kamal', require: false
gem 'thruster', require: false

group :development, :test do
  # Debugging, security checks, and linting
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'debug', platforms: %i[ mri windows ], require: 'debug/prelude'
  gem 'rubocop-rails-omakase', require: false

  # Test framework
  gem 'rspec-rails', '~> 8.0.0'
  gem 'factory_bot_rails'

  # Email testing
  gem 'letter_opener'
end

group :development do
  # Rails console/debugging helpers
  gem 'web-console'
end

group :test do
  # Test assertions
  gem 'shoulda-matchers', '~> 7.0'
end
