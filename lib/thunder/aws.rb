#######################
# AMAZON WEB SERVICES #
#######################
#
# Most things are handled by the aws_sdk
#
OLD_TRIGGER = "OLD"
module Thunder
  class AWS < CloudImplementation
    def initialize(thunder_config, options={})
      super(options)

      config_aws(thunder_config)
      @cfm = ::AWS::CloudFormation.new
      @ec2 = ::AWS::EC2.new
      @kpc = ::AWS::EC2::KeyPairCollection.new

      @stacks = @cfm.stacks
    end

    #################
    # Native Config #
    #################

    def self.get_native
      native_path = ENV["HOME"] + "/.aws/config"

      if File.exists? native_path
        source = ParseConfig.new(native_path)
        config = source["default"]

        return config
      end

      puts native_path+" not found."
      nil
    end

    ##############
    # Manipulate #
    ##############
    def create(name, raw_template, *parameterss)
      template = load_template(raw_template)
      parameters = load_parameters(parameterss)
      filtered_parameters = filter_parameters(parameters, template)

      begin
        @cfm.stacks.create(name,
                           template.to_json,
                           :parameters => filtered_parameters)
      rescue ::AWS::CloudFormation::Errors::AlreadyExistsException
        puts "Stack already exists."
      end
    end

    def delete(name)
      if @cfm.stacks[name].exists?
        puts "Stack '"+name+"' exists."
        output = @cfm.stacks[name].delete
        puts "Delete request submitted."
      else
        puts "Stack '"+name+"' does not exist."
      end
    end

    def update(name, template, parameterss)
      #load all the crap
      template = load_template(template, rmt_template=true)
      parameters = load_parameters(parameterss)
      filtered_parameters = filter_parameters(parameters, template)
      formatted_parameters = aws_parameter_json(filtered_parameters)

      #do it
      @cfm.stacks[name].update(:template => template.to_json,
                               :parameters => formatted_parameters)
    end

    ###########
    # Observe #
    ###########
    def stacks
      @cfm.stacks.map { |stak| { :Name=>stak.name,
          :Status=>stak.status,
          :Reason => stak.status_reason } }
    end

    def outputs(name)
      @cfm.stacks[name].outputs.map { |out| { :Key=>out.key, :Value=>out.value } }
    end

    def events(name)
      (Array @stacks[name].events).reverse
    end

    # Support Functions for poll events #
    #returns a lambda that, given some x, returns a unique identifier for x
    def event_id_getter
      lambda { |x| x.event_id }
    end

    #returns a lambda that, given some x, returns true if x is a tail_event that
    #indicates polling should terminate
    def poll_terminator(name)
      lambda { |x| x.resource_type == 'AWS::CloudFormation::Stack' && x.logical_resource_id == name }
    end

    #returns a lambda that, given some x, returns the resource_status for x
    def resource_status
      lambda { |x| x.resource_status }
    end

    #############
    # Utilities #
    #############

    def template_parsers(rmt_template)
      extras = @template_generation_extras
      extras["OrchestrationEnvironment"] = "cloudformation"
      return {
        ".json" => lambda {|r| JSON.parse(File.read(r)) },
        ".rb"   => lambda {|r| JSON.parse(CfnDsl::eval_file_with_extras(r, extras).to_json)},
        "" => lambda { |x|
          raise Exception.new("Template value: #{x} -- Did you leave off the file extension?") unless rmt_template
          JSON.parse(@cfm.stacks[x].template) }
      }
    end

    def load_template(template, rmt_template = false)
      return hashload(template, template_parsers(rmt_template))
    end

    # Parameters-related #

    def remote_param_default(name)
      @cfm.stacks[name].outputs.inject({}) {|hash,item|
        hash[item.key] = item.value; hash }
    end

    def remote_param_old(long_name)
      ext = File.extname(long_name)
      name = long_name[0 ... -ext.length]
      @cfm.stacks[name].parameters.inject({}) { |hash,item|
        hash[item[0]] = OLD_TRIGGER; hash }
    end

    def parameters_parsers()
      return {
        ".json" => lambda {|r| JSON.parse(File.read(r)) },
        ".yaml" => lambda {|r| YAML.load(File.read(r)) },
        ".OLD" => lambda {|x| remote_param_old(x) },
        "" =>  lambda {|x| remote_param_default(x) }
      }
    end

    #this method is identical to that in the other class--migrate up to
    #CloudFormation class?
    def load_parameters(parameterss)
      default = lambda { |x| remote_param_default(x) }
      old = lambda { |x| remote_param_old(x)}

      remote_behavior = {"" => default, ".OLD" => old}

      parameters = plural_hashload(parameterss, parameters_parsers)
      return parameters
    end

    def filter_parameters(parameters, template)
      #filter parameters for those relevant
      filtered_parameters = parameters.select { |key,val|
        template["Parameters"].has_key?(key)
      }
      return filtered_parameters
    end

    def display_events(events, options)
      table = []
      events.each do |event|
        order = [:@stack_name, :@resource_type, :@resource_status,
                 :ETC,
                 :@stack_id, :@timestamp]

        vars = event.instance_variables

        hash = {}
        vars -= [:@stack] #special case

        if not options[:verbose]
          vars -= [:@event_id,
                   :@physical_resource_id,
                   :@stack_id,
                   :@resource_properties]
        end

        for var in CloudImplementation::sort_override(vars, order) do
          hash[var] = event.instance_variable_get(var)
        end
        table << hash
      end
      Formatador.display_table(table)
    end

    ############
    # Keypairs #
    ############

    class Keypair < CloudImplementation::Keypair
      # get the a public key of name from the stack
      def initialize(name, config, pk_path = nil)
        if pk_path == nil
          super(name)
        else
          super(name, pk_path = pk_path)
        end

        @name = name

        temp = Thunder::AWS.new(config)
        @ec2 = temp.ec2
        @kpc = temp.kpc
      end

      def get_pub
        key_pair = @ec2.key_pairs.select { |x| x.name == @name }

        if key_pair.length > 1
          pp key_pair
          raise Exception.new("Key pair name ambiguous?")
        elsif key_pair.length == 0
          return nil
        else
          return key_pair[0]
        end

        if no_local and no_aws
          puts "WARNING: Literally nothing has changed."
        end
      end

      def delete
        get_pub.delete
      end

      #public key -> stack
      # (this is the heart of "create")
      def send_key(public_key)
        @ec2.key_pairs.import(@name, public_key)
      end
    end

    ###############
    # Connections #
    ###############

    #convert hash to an AWS parameter json, which is a list of hashes of
    #   [{"key" => key, "value" => value}, ... ]
    #hash values "USE_PREVIOUS_VALUE" trigger special behavior
    OLD_TRIGGER = "USE_PREVIOUS_VALUE"
    def aws_parameter_json(hash)
      return hash.map { |k,v| Hash[[["ParameterKey", k], v == OLD_TRIGGER ?
                                    ["UsePreviousValue", true] : ["ParameterValue", v]]] }
    end

    def config_aws(thunder_config)
      creds = {}
      creds[:id] = thunder_config["aws_access_key_id"]
      creds[:secret] = thunder_config["aws_secret_access_key"]
      creds[:region] = thunder_config["region"]

      ::AWS.config(:region => creds[:region],
                 :access_key_id => creds[:id],
                 :secret_access_key => creds[:secret] )
    end


    #####################
    # Steal Connections #
    #####################
    # Because encapsulation is for the weak-minded.
    # ... really, because it's needed for the keypair stuff.

    def cfm
      @cfm
    end

    def ec2
      @ec2
    end

    def kpc
      @kpc
    end

  end
end
