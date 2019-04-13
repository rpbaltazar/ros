# frozen_string_literal: true

require 'thor/group'

module Ros
  module Generators
    class Env < Thor::Group
      include Thor::Actions
      attr_accessor :name, :options
      desc 'Generate a new Ros service'

      def self.source_root; Pathname(File.dirname(__FILE__)).join('../../../files/project').to_s end

      def keys; @keys ||= OpenStruct.new end

      def generate
        # TODO Thor seems to not allow attributes to be set on an instance of this class
        in_root do
          directory('.')
          create_file 'services/.keep'
          create_file 'containers/nginx/services.conf'
          gsub_file('Dockerfile', 'service', name)
        end
      end

      def generate_secrets
        require 'securerandom'
        keys.rails_master_key = SecureRandom.hex
        keys.secret_key_base = SecureRandom.hex(64)
        keys.platform__jwt__encryption_key = SecureRandom.hex
        keys.platform__credential__salt = rand(10 ** 9)
        keys.platform__encryption_key = SecureRandom.hex
      end

      def env_content
        create_file '.env' do <<~HEREDOC
          # .env
          # This file was generated by 'ros init'
          # Compose Variables
          ros_dir=./ros
          COMPOSE_PROJECT_NAME=#{name}

          COMPOSE_FILE=docker-compose.yml:ros/docker-compose.yml

          # mount host's source for dev:
          # COMPOSE_FILE=docker-compose.yml:docker-compose-dev.yml:ros/docker-compose.yml

          # mount host's ros source for dev:
          # COMPOSE_FILE=docker-compose.yml:docker-compose-dev.yml:ros/docker-compose.yml:ros/docker-compose-dev.yml
          HEREDOC
        end
      end

      def app_env_content
        create_file 'app.env' do <<~HEREDOC
          # app.env
          # This file was generated by 'ros init'
          # ENVs read by the docker-compose.yml file to set common values across all services
          # If the direnv package is installed these values will automatically be set as shell variables upon entering this directory
          # Otherwise, to set these values manually in the shell do this:
          # $ set -a
          # $ source app.env

          # Rails
          SECRET_KEY_BASE=#{keys.secret_key_base}
          RAILS_MASTER_KEY=#{keys.rails_master_key}
          # RAILS_DATABASE_HOST=localhost

          # Service
          PLATFORM__PARTITION_NAME=#{name}

          # JWT
          PLATFORM__JWT__ENCRYPTION_KEY=#{keys.platform__jwt__encryption_key}
          PLATFORM__JWT__ISS=#{options.uri.scheme}://iam.#{options.uri.to_s.split('//').last}
          PLATFORM__JWT__AUD=#{options.uri}

          # Hosts to which these services respond to
          PLATFORM__HOSTS=#{options.uri.host}

          # Postman workspace to which API documentation updates are written
          PLATFORM__POSTMAN__WORKSPACE=#{options.uri.host}
          PLATFORM__POSTMAN__API_KEY=

          PLATFORM__API_DOCS__SERVER__HOST=#{options.uri}

          # SDK
          PLATFORM__CONNECTION__TYPE=host
          PLATFORM__EXTERNAL_CONNECTION_TYPE=path

          # IAM specific:
          PLATFORM__CREDENTIAL__SALT=#{keys.platform__credential__salt}

          # Comm specific:
          PLATFORM__ENCRYPTION_KEY=#{keys.platform__encryption_key}
          HEREDOC
        end
      end

      def docker_compose_env_content
        create_file 'docker-compose.env' do <<~HEREDOC
          # docker-compose.env
          # This file was generated by 'ros init'

          # Rails
          RAILS_DATABASE_HOST=db
          HEREDOC
        end
      end

      def rakefile_content
        create_file 'Rakefile' do <<~HEREDOC
          load 'ros/tasks/Rakefile'
          HEREDOC
        end
      end

      def finish_message
        say "\nCreated envs at #{destination_root}"
      end
    end
  end
end
