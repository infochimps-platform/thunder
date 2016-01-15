require 'base64'

#######################
# OPENSTACK           #
#######################
# How things are obtained:
#   1) If it's in 'fog', try that.
#   2) Make an API call.
module Thunder
  module CloudImplementation
    class Openstack
      include CloudImplementation

      attr_reader :compute

      def self.native_config(path = nil)
        {
          'openstack_auth_url'    => ENV['OS_AUTH_URL'],
          'openstack_username'    => ENV['OS_USERNAME'],
          'openstack_tenant'      => ENV['OS_TENANT_NAME'],
          'openstack_api_key'     => ENV['OS_PASSWORD'],
          'openstack_tenant_id'   => ENV['OS_TENANT_ID'],
          'openstack_region_name' => ENV['OS_REGION_NAME'],
          'connection_options'    => {}
        }
      end

      def initialize(options)
        super(options)
        @config = config_os options
      end

      def stacks
        @stacks ||= hash_stacks orch.stacks
      end

      def compute
        @compute ||= Fog::Compute.new(@config.merge(provider: 'OpenStack'))
      end

      ##############
      # Manipulate #
      ##############
      def create(name, raw_template, *parameterss)
        template = load_template(raw_template)
        parameters = load_parameters(parameterss)
        filtered_parameters = filter_parameters(parameters, template)

        template_text = get_template_text(template)

        begin
          orch.stacks.create({:stack_name => name,
                                :template_url => template_text,
                                :parameters => filtered_parameters,
                                :timeout_mins => 600
                              })
        rescue Exception => e #idk the duplicate exception yet
          raise e
        end
      end

      def delete(name)
        stack_id = get_stack_id(name)
        orch.delete_stack(name, stack_id)
      end

      def update(name, template, parameterss)
        #load all the crap
        template = load_template(template)

        # For some reason yet undertermined, trying to load old parameter values in openstack does not
        # work. Luckily it is not a terribly important use case. Here we work around the problem by
        # simply ingoring the directive to load old parameterss.

        parameterss.reject! {|x| x=~/\.OLD$/}

        parameters = load_parameters(parameterss)
        filtered_parameters = filter_parameters(parameters, template)

        template_text = get_template_text(template)

        #do it
        stack_id = get_stack_id(name)

        orch.update_stack(stack_id, name,
                           {:stack_name => name,
                             :template_url => template_text,
                             :parameters => filtered_parameters,
                             :existing_parameters => true,
                             :timeout_mins => 600
                           })
      end


      ###########
      # Observe #
      ###########
      def present_stacks
        orch.stacks.map { |stak| { :Name   => stak.stack_name,
            :Status => stak.stack_status,
            :Reason => stak.stack_status_reason } }
      end

      def status(name)
        orch.stacks[name].status
      end

      def outputs(name)
        outputs = os_outputs(name, get_stack_id(name))
        outputs.map { |out| {:Key => out["output_key"],
            :Value => out["output_value"],
            :Description => out["description"] } }
      end

      def events(name)
        os_events(name, get_stack_id(name))
      end

      # Support Functions for poll events #
      #returns a lambda that, given some x, returns a unique identifier for x
      def event_id_getter
        lambda { |x| x["id"] } #maybe not right?
      end

      #returns a lambda that, given some x, returns true if x is a tail_event that
      #indicates polling should terminate
      def poll_terminator(name)
        # lambda { |x| x["logical_resource_id"] == name }
        #currently, goes forever. no clue what this should be. ^^^ that's my best
        #guess so far.
        lambda { |x| false }
      end

      #returns a lambda that, given some x, returns the resource_status for x
      def resource_status
        lambda { |x| x["resource_status"] }
      end


      #############
      # Utilities #
      #############

      def template_parsers(rmt_template)
        extras = @template_generation_extras
        extras.push [:raw, 'OrchestrationEnvironment = "heat"']
        {
          '.json' => lambda{ |r| data = nil; open(r){ |f| data = JSON.parse(f.read) } ; data },
          '.rb'   => lambda{ |r| JSON.parse CfnDsl.eval_file_with_extras(r, extras).to_json },
          ''      => lambda{ |r| raise Exception.new 'Openstack templates must be manually resupplied on update.' }
        }
      end

      def load_template(template, rmt_template = false)
        return hashload(template, template_parsers(rmt_template))
      end

      # Parameters-related #

      def remote_param_default(name)
        stack_id = get_stack_id(name)
        os_outputs(name, stack_id).inject({}){|h,v| h[v["output_key"]]=v["output_value"];h}
      end

      def remote_param_old(long_name)
        ext = File.extname(long_name)
        name = long_name[0 ... -ext.length]
        stack_id = get_stack_id(name)
        os_parameters(name,stack_id).inject({}) { |hash, item|
          hash[item[0]] = OLD_TRIGGER; hash }
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

      def parameters_parsers()
        return {
          ".json" => lambda {|r| JSON.parse(File.read(r)) },
          ".yaml" => lambda {|r| load_yaml_parameters(r) },
          ".OLD" => lambda {|x| remote_param_old(x) },
          "" =>  lambda {|x| remote_param_default(x) }
        }
      end

      #this method is identical to that in the other class--migrate up to
      #CloudFormation class?
      def load_parameters(parameterss)
        parameters = plural_hashload(parameterss, parameters_parsers)
        return parameters
      end

      def filter_parameters(parameters, template)
        #filter parameters for those relevant
        tparms = template["Parameters"] || template["parameters"]

        filtered_parameters = parameters.select { |key,val|
          tparms.has_key?(key)
        }
        return filtered_parameters
      end

      #get the id of the stack called stack_name
      #stacks is a hash such that {name => stack, ...}
      def get_stack_id(stack_name)
        stacks[stack_name].id
      end

      def display_events(events, options)
        table = []
        events.each do |event|
          event.delete("links")
          if not options[:verbose]
            event.delete("id")
            event.delete("physical_resource_id")
          end
        end
        table = events
        Formatador.display_table(table)
      end

      ############
      # Keypairs #
      ############

      def get_pubkey name
        key_pairs = compute.list_key_pairs.body["keypairs"]
        key_pairs = key_pairs.map { |kp| kp["keypair"] } #flatten

        key_pair = key_pairs.select { |x| x["name"] == name }

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
        compute.delete_key_pair name
      end

      def send_key(name, public_key)
        compute.create_key_pair(name, public_key)
      end

      ###############
      # Connections #
      ###############


      # FOG-RELATED CONNECTION STUFF #
      def config_os(os_vars)
        creds = {}

        creds[:openstack_auth_url] = os_vars[:openstack_auth_url]
        creds[:openstack_username] = os_vars[:openstack_username]
        creds[:openstack_tenant] = os_vars[:openstack_tenant]
        creds[:openstack_api_key] = os_vars[:openstack_api_key]
        creds[:openstack_project_domain] = os_vars[:openstack_project_domain]
        creds[:openstack_user_domain] = os_vars[:openstack_user_domain]
        creds[:connection_options] = os_vars[:connection_options] || {}

        creds[:connection_options] ||= {} #JSON.parse(creds[:connection_options]) if creds[:connection_options]
        return creds
      end

      def orch
        @orch ||= Fog::Orchestration.new({ provider: 'openstack'}.merge(@config))
      end

      #fog returns arrays of stacks. we want a hash. to look stuff up.
      def hash_stacks(arr)
        return Hash[arr.map { |x| [x.stack_name, x] }]
      end


      # API-RELATED CONNECTION STUFF #
      #
      def os_outputs(stack_name, stack_id)
        api_stub = "/stacks/#{stack_name}/#{stack_id}"
        return os_retrieve(api_stub, "stack/outputs")
      end

      def os_parameters(stack_name, stack_id)
        api_stub = "/stacks/#{stack_name}/#{stack_id}"
        return os_retrieve(api_stub, "stack/parameters")
      end

      def os_events(stack_name, stack_id)
        api_stub = "/stacks/#{stack_name}/#{stack_id}/events"
        return os_retrieve(api_stub, "events")
      end

      #does a GET request for a particular stack. Gets the Hash of the path of
      #keys provided in stack_hole
      PATH_DIVIDER = "/"
      def os_retrieve(api_stub, path)
        tenant = @config[:openstack_tenant]
        user = @config[:openstack_username]
        pass = @config[:openstack_api_key]
        auth_url = @config[:openstack_auth_url]

        #auth
        auth = os_auth(auth_url, tenant, user, pass)
        token = auth["access"]["token"]["id"]
        svc_catalog = auth["access"]["serviceCatalog"]
        svc_catalog = Hash[svc_catalog.map { |x| [x["name"], x] }]

        #retrieve
        api_url = svc_catalog["heat"]["endpoints"][0]["publicURL"]
        api_call = api_url+api_stub
        response = os_api("GET", api_call, token, {})
        response = JSON.parse(response)

        # get the result from the desired path
        path = path.split(PATH_DIVIDER)
        cursor = response
        path.each do |k|
          cursor = cursor[k]
        end
        return cursor
      end

      # Lowest-level interfaces #
      #get authentication token and relevant endpoints
      def os_auth(url,tenant,user,pass)

        authdata = {"auth" =>
          {"tenantName" => tenant,
            "passwordCredentials" =>
            {"username" => user,
              "password" => pass }}}
        client = RestClient::Request.new(
                                         :method => "POST",
                                         :url => url,
                                         :headers => {"Content-Type" => "application/json",
                                           "Accept"       => "application/json"},
                                         :payload => authdata.to_json,
                                         )

        response = client.execute
        return JSON.parse(response)
      end


      def os_api(method, url, token, data)

        client = RestClient::Request.new(
                                         :method => method,
                                         :url => url,
                                         :headers => {"User-Agent"   => "thunder",
                                           "X-Auth-Token" => token},
                                         :payload => data.to_json ,
                                         )

        response = client.execute
        return response

      end
    end
  end
end
