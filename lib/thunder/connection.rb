module Thunder
  module Connection
    # This class deals with cross cutting concerns of loading up the thunder
    # configuration files, and getting back end connections to aws or
    # openstack, depending on the environment.

    def con
      if !@connection then
        # check config file
        config = load_config
        if config["flavor"] == "openstack"
          contype = :openstack
        elsif config["flavor"] == "aws"
          contype = :aws
        end

        # TODO: add and environment variable selector for stack type?

        # check cli opts
        if config_options[:openstack]
          contype = :openstack
        elsif config_options[:aws]
          contype = :aws
        end

        # resolve
        if not contype
          raise Exception.new("No con type chosen. Use options -o or -a, or run thunder config.")
        elsif contype == :openstack
          @connection = Thunder::Openstack.new(config, options)
        elsif contype == :aws
          @connection = Thunder::AWS.new(config, options)
        end
      end

      return @connection
    end

    def config_options
      return options
    end

    def load_config(config_file = nil)
      config_file ||= config_options[:config_file]
      config_section = config_options[:config_file_section]

      if config_file.nil?
        $stderr.puts "Missing config"
        exit 1
      end

      config_filename = File.expand_path(config_file )
      conf = YAML.load(File.open(config_filename).read)

      config = conf[ config_section ]

      unless config
        $stderr.puts "'#{config_filename}' is missing config section '#{config_section}'"
        exit 1
      end

      config.inject({}) { |hash,(k,v)| hash[k] = v.is_a?(String) ? v.strip : v; hash }
    end
  end
end
