# frozen_string_literal: true
require 'pry'

module Ros
  module Cognito
    class Engine < ::Rails::Engine
      config.generators.api_only = true
      config.generators do |g|
        g.test_framework :rspec, fixture: true
        g.fixture_replacement :factory_bot, dir: 'spec/factories'
      end

      # Adds this gem's db/migrations path to the enclosing application's migraations_path array
      # https://github.com/rails/rails/issues/22261
			initializer :append_migrations do |app|
				config.paths['db/migrate'].expanded.each do |expanded_path|
					app.config.paths['db/migrate'] << expanded_path
					ActiveRecord::Migrator.migrations_paths << expanded_path
        end unless app.config.paths['db/migrate'].first.include? 'spec/dummy'
			end

			initializer :console_methods do |app|
        Ros.config.factory_paths += Dir[Pathname.new(__FILE__).join('../../../../spec/factories')]
        Ros.config.model_paths += config.paths['app/models'].expanded
      end if Rails.env.development?

      config.after_initialize do
        Settings.service['name'] = 'cognito'
        Settings.service['policy_name'] = 'Cognito'
      end
    end
  end
end
