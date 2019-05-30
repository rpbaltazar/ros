# frozen_string_literal: true
# https://nandovieira.com/creating-generators-and-executables-with-thor
require 'thor'

# TODO: move new, generate and destroy to ros/generators
# NOTE: it should be possible to invoke any operation from any of rake task, cli or console

module Ros
  class Cli < Thor
    def self.exit_on_failure?; true end

    check_unknown_options!
    class_option :verbose, type: :boolean, default: false

    desc 'version', 'Display version'
    map %w(-v --version) => :version
    def version; say "Ros #{VERSION}" end

    desc 'new NAME HOST', "Create a new Ros platform project. \"ros new my_project\" creates a\n" \
      'new project called MyProject in "./my_project"'
    option :force, type: :boolean, default: false, aliases: '-f'
    def new(*args)
      name = args[0]
      host = URI(args[1] || 'http://localhost:3000')
      args.push(:nil, :nil, :nil)
      FileUtils.rm_rf(name) if Dir.exists?(name) and options.force
      raise Error, set_color("ERROR: #{name} already exists. Use -f to force", :red) if Dir.exists?(name)
      require_relative 'generators/project/project_generator.rb'
      generator = Ros::Generators::ProjectGenerator.new(args)
      generator.destination_root = name
      generator.invoke_all
      require_relative 'generators/env/env_generator.rb'
      %w(console local development production).each do |env|
        generator = Ros::Generators::EnvGenerator.new([env, name, host, :nil])
        generator.destination_root = name
        generator.invoke_all
      end
      require_relative 'generators/core/core_generator.rb'
      generator = Ros::Generators::CoreGenerator.new(args)
      generator.destination_root = name
      generator.invoke_all
      require_relative 'generators/sdk/sdk_generator.rb'
      generator = Ros::Generators::SdkGenerator.new(args)
      generator.destination_root = name
      generator.invoke_all
    end

    desc 'generate TYPE NAME', 'Generate a new environment or service'
    map %w(g) => :generate
    option :force, type: :boolean, default: false, aliases: '-f'
    def generate(artifact, *args)
      raise Error, set_color("ERROR: Not a Ros project", :red) if Ros.root.nil?
      valid_artifacts = %w(service env)
      raise Error, set_color("ERROR: invalid artifact #{artifact}. valid artifacts are: #{valid_artifacts.join(', ')}", :red) unless valid_artifacts.include? artifact
      raise Error, set_color("ERROR: must supply a name for #{artifact}", :red) if %w(service env).include?(artifact) and args[0].nil?
      require_relative "generators/#{artifact}/#{artifact}_generator.rb"
      name = args[0]
      args.push(File.basename(Dir.pwd))
      generator = Object.const_get("Ros::Generators::#{artifact.capitalize}Generator").new(args)
      generator.options = options
      # generator.destination_root = '.'
      # generator.destination_root = Ros.root
      generator.invoke_all
    end

    # TODO: refactor setting action to :destroy
    desc 'destroy TYPE NAME', 'Destroy an environment or service'
    map %w(d) => :destroy
    def destroy(artifact, name = nil)
      valid_artifacts = %w(service)
      raise Error, set_color("ERROR: invalid artifact #{artifact}. valid artifacts are: #{valid_artifacts.join(', ')}", :red) unless valid_artifacts.include? artifact
      raise Error, set_color("ERROR: must supply a name for service", :red) if artifact.eql?('service') and name.nil?
      require_relative "generators/#{artifact}.rb"
      generator = Object.const_get("Ros::Generators::#{artifact.capitalize}").new
      generator.destination_root = artifact.eql?('service') ? "services/#{name}" : "services/#{name}#{artifact.eql?('sdk') ? '_' : '-'}#{artifact}"
      generator.options = options
      generator.name = name
      generator.project = File.basename(Dir.pwd)
      generator.behavior = :revoke
      generator.invoke_all
    end

    # TODO: Handle show and edit as well
    desc 'lpass ACTION', 'Transfer the contents of app.env to/from a Lastpass account'
    option :username, aliases: '-u'
    def lpass(action)
      raise Error, set_color("ERROR: invalid action #{action}. valid actions are: add, show, edit", :red) unless %w(add show edit).include? action
      raise Error, set_color("ERROR: Not a Ros project", :red) unless File.exists?('app.env')
      lpass_name = "#{File.basename(Dir.pwd)}/development"
      %x(lpass login #{options.username}) if options.username
      %x(lpass add --non-interactive --notes #{lpass_name} < app.env)
    end

    desc 'console', 'Start the Ros console (short-cut alias: "c")'
    map %w(c) => :console
    def console(env = nil)
      Ros.load_env(env) if (env and env != Ros.default_env)
      Pry.start
    end

    desc 'list', 'List configuration objects'
    map %w(ls) => :list
    def list(what = nil)
      STDOUT.puts 'Options: services, profiles, images' if what.nil?
      STDOUT.puts "#{Settings.send(what).keys.join("\n")}" unless what.nil?
    end

    desc 'server PROFILE', 'Start all services (short-cut alias: "s")'
    option :build, type: :boolean, aliases: '-b'
    option :daemon, type: :boolean, aliases: '-d'
    option :environment, type: :string, aliases: '-e', default: 'local'
    option :initialize, type: :boolean, aliases: '-i'
    map %w(s) => :server
    def server
      Ros.load_env(options.environment) if options.environment != Ros.default_env
      Ros.ops_action(:service, :provision, options)
    end

    desc 'reset SERVICE', 'Reset a service'
    def reset(service)
      %x(docker-compose stop #{service})
      %x(docker-compose rm #{service})
      %x(docker-compose up -d #{service})
      %x(docker container exec #{Settings.platform.environment.partition_name}_nginx_1 nginx -s reload)
    end

    desc 'ps', 'List running services'
    def ps
      puts %x(docker-compose ps)
    end

    desc 'restart all non-platform services', 'Restarts all non-platform services'
    def restart
      # TODO: needs to get the correct name of the worker, etc
      # Settings.services.each_with_object([]) do |service, ary|
      #   ary.concat service.profiles
      # end
      %x(docker-compose stop #{Settings.services.keys.join(' ')})
      %x(docker-compose up -d #{Settings.services.keys.join(' ')})
      sleep 3
      %x(docker container exec #{Settings.platform.environment.partition_name}_nginx_1 nginx -s reload)
    end
  end
end
