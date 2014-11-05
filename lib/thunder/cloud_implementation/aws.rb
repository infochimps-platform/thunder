require 'base64'

######################
# AMAZON WEB SERVICES #
#######################
#
# Most things are handled by the aws_sdk
#
OLD_TRIGGER = "OLD"
module Thunder
  module CloudImplementation
    class AWS
      include CloudImplementation

      def self.native_config(path = nil)
        native_path = path || File.join(ENV['HOME'].to_s, '.aws/config')
        source = ParseConfig.new native_path
        source['default']
      rescue => e
        warn e.message
        {}
      end

      def initialize(options)
        super(options)
        config_aws options
      end

      def cfm
        @cfm ||= ::AWS::CloudFormation.new
      end

      def ec2
        @ec2 ||= ::AWS::EC2.new
      end

      def kpc
        @kpc ||= ::AWS::EC2::KeyPairCollection.new
      end

      # This is hard-coded at the moment to expediate development.
      # Expect this to change in the future to become more dynamic
      # and more secure
      def s3
        @s3 ||= ::AWS::S3.new(region: 'us-east-1')
      end

      def config_aws(thunder_config)
        ::AWS.config(region: thunder_config[:region],
                     access_key_id: thunder_config[:aws_access_key_id],
                     secret_access_key: thunder_config[:aws_secret_access_key])
      end

      ##############
      # Manipulate #
      ##############
      def create(name, raw_template, *parameterss)
        template = load_template(raw_template)
        parameters = load_parameters(parameterss)
        filtered_parameters = filter_parameters(parameters, template)

        begin
          cfm.stacks.create(name, template.to_json, parameters: filtered_parameters)
        rescue ::AWS::CloudFormation::Errors::AlreadyExistsException
          puts "Stack already exists."
        end
      end

      def delete(name)
        if cfm.stacks[name].exists?
          puts "Stack '"+name+"' exists."
          output = cfm.stacks[name].delete
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
        cfm.stacks[name].update(:template => template.to_json,
                                :parameters => formatted_parameters)
      end

      # This is hard-coded at the moment to expediate development.
      # Expect this to change in the future to become more dynamic
      # and more secure
      def remote_file_bucket
        find_or_create_bucket('filestore.platform.infochimps')
      end

      def find_or_create_bucket(name, options = {})
        return s3.buckets[name] if s3.buckets[name].exists?
        s3.buckets.create(name, options)
      end

      def persistent_key params
        key = params[:key] || params[:filename]
        File.join(params[:stack], key)
      end

      def persistent_base_url(params)
        s3file = remote_file_bucket.objects[persistent_key params]
        s3file.public_url
      end

      def persist_remote_file params
        s3file = remote_file_bucket.objects[persistent_key params]
        s3file.write(file: params[:filename], acl: :public_read)
        s3file.public_url
      end

      def retrieve_remote_file params
        s3file = remote_file_bucket.objects[persistent_key params]
        File.open(params[:filename], 'w') do |f|
          s3file.read do |chunk|
            f.write chunk
          end
        end
      end

      ###########
      # Observe #
      ###########

      def present_stacks
        cfm.stacks.map { |stak| { :Name=>stak.name,
            :Status=>stak.status,
            :Reason => stak.status_reason } }
      end

      def outputs(name)
        cfm.stacks[name].outputs.map { |out| { :Key=>out.key, :Value=>out.value } }
      end

      def events(name)
        (Array cfm.stacks[name].events).reverse
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
        extras.push [:raw, 'OrchestrationEnvironment = "cloudformation"']
        return {
          ".json" => lambda {|r| JSON.parse(File.read(r)) },
          ".rb"   => lambda {|r| JSON.parse(CfnDsl::eval_file_with_extras(r, extras).to_json)},
          "" => lambda { |x|
            raise Exception.new("Template value: #{x} -- Did you leave off the file extension?") unless rmt_template
            JSON.parse(cfm.stacks[x].template) }
        }
      end

      def load_template(template, rmt_template = false)
        return hashload(template, template_parsers(rmt_template))
      end

      # Parameters-related #

      def remote_param_default(name)
        cfm.stacks[name].outputs.inject({}){ |hash,item| hash[item.key] = item.value; hash }
      end

      def remote_param_old(long_name)
        ext = File.extname(long_name)
        name = long_name[0 ... -ext.length]
        cfm.stacks[name].parameters.inject({}){ |hash,item| hash[item[0]] = OLD_TRIGGER; hash }
      end

      def load_yaml_parameters(file)
        o = YAML.load(File.read(file))
        o.keys.each do |k|
          if o[k].respond_to? :has_key?
            o[k] = Base64.strict_encode64( o[k]["base64"]) if o[k].has_key? "base64"
          end
        end
        return o
      end

      def parameters_parsers
        {
          '.json' => lambda{ |r| JSON.parse File.read(r) },
          '.yaml' => lambda{ |r| YAML.load File.read(r) },
          '.OLD'  => lambda{ |x| remote_param_old x },
          ''      => lambda{ |x| remote_param_default x },
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

      # Keypair Methods

      def get_pubkey name
        key_pair = ec2.key_pairs.select { |x| x.name == name }

        if key_pair.length > 1
          pp key_pair
          raise Exception.new("Key pair name ambiguous?")
        elsif key_pair.length == 0
          return nil
        else
          return key_pair[0]
        end
      end

      def delete_pubkey name
        get_pubkey(name).delete
      end

      def send_key(name, public_key)
        ec2.key_pairs.import(name, public_key)
      end

    end
  end
end
