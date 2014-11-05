module Thunder
  module Connection
    def thor_options
      options.to_hash.symbolize_keys
    end

    def configuration
      return @configuration if @configuration
      conf = Configuration.new(location: thor_options[:config_file], scope: thor_options[:config_section])
      @configuration = conf.populate!
    end

    def implementation_selector
      flavor   = thor_options[:aws] ? :aws : nil
      flavor ||= thor_options[:openstack] ? :openstack : nil
      flavor ||= configuration[:flavor]
      flavor ||= :aws
      flavor.to_sym
    end

    def con
      return @connection if @connection
      params = configuration.to_hash.merge thor_options
      case implementation_selector
      when :aws
        @connection = Thunder::CloudImplementation::AWS.new params
      when :openstack
        @connection = Thunder::CloudImplementation::Openstack.new params
      end
      @connection
    end
  end
end
