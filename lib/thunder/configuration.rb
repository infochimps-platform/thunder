module Thunder
  class Configuration
    def self.default_location
      config_dir = ENV['HOME'] ? File.join(ENV['HOME'], '.thunder') : Dir.pwd
      File.join(config_dir, 'config.yaml')
    end

    attr_reader :location, :scope

    def initialize(params = {})
      @location = params[:location] || self.class.default_location
      @scope    = (params[:scope]   || :default).to_sym
    end

    def aws_options
      %w(aws_access_key_id aws_secret_access_key region).map(&:to_sym)
    end

    def os_options
      %w(openstack_auth_url openstack_username openstack_tenant openstack_api_key connection_options).map(&:to_sym)
    end

    def all_options
      aws_options + os_options
    end

    def empty_configuration
      all_options.each_with_object({}){ |opt, conf| conf[opt] = nil }
    end

    def update(new_values)
      scoped_access.merge! new_values.deep_symbolize_keys
    end

    def to_hash
      scoped_access.dup
    end

    def [](key)
      scoped_access[key.to_sym]
    end

    def all_scopes
      @internal.keys
    end

    def scoped_access
      @internal[scope] ||= empty_configuration
      @internal[scope]
    end

    def populate!(attributes = nil)
      @internal = attributes || read_from_disk || { default: empty_configuration }
      self
    end

    def internal_with_placeholders
      all_scopes.each_with_object({}) do |key, conf|
        conf[key] = empty_configuration.merge @internal[key]
      end
    end

    def read_from_disk
      (YAML.load File.read(location)).deep_symbolize_keys rescue nil
    end

    def write_to_disk
      FileUtils.mkdir_p File.dirname(location)
      File.open(location, 'wb') do |f|
        f.puts internal_with_placeholders.deep_stringify_keys.to_yaml
      end
    end
  end
end
