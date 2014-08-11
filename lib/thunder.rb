require 'aws-sdk'
require 'json'
require 'cfndsl'
require 'pp'
require 'sshkey'
require 'fog'
require 'rest_client'
require 'thor'
require 'formatador'
require 'parseconfig'

#########################################################################
# Thor + Cloud == Thunder
#   at least version (0.8)
# Dan Simonson, Infochimps, Summer 2014
#
#   Thunder is a Thor-implemented set of tools for cloud formation.
#
#   thunder_cons is a support library for Thunder containing classes that
#   act as a common, indistinguishable wrapper for AWS and OpenStack.
#
#
#########################################################################

# abstract connection class:
#   - throws errors if something hasn't been implemented
#   - allows sharing of common methods (what few there may be)
class CloudImplementation
  def self.raise_undeclared
    raise Exception.new("This hasn't been implemented yet.")
  end

  # Constructor #
  def initialize(options)
    @options = options

    # This builds up a list of extra parameters to pass to cfndsl.
    sym_lookup = { ".yaml" => :yaml, ".json" => :json }
    @template_generation_extras = (options["generation_parameters"] || []).map {|f| [sym_lookup[File.extname(f)], f] }
    bad_generators = @template_generation_extras.select {|f| !f[0] }.map {|f| f[1]}
    throw Exception.new("Unknown generation parameter file types: #{bad_generators.join ', '}") if bad_generators.length > 0

  end

  # Manipulator Methods #
  def create
    CloudImplementation::raise_undeclared
  end

  def delete
    CloudImplementation::raise_undeclared
  end

  def update
    CloudImplementation::raise_undeclared
  end

  # Viewers Methods #

  def parameters
    CloudImplementation::raise_undeclared
  end

  def stacks
    CloudImplementation::raise_undeclared
  end

  def outputs
    CloudImplementation::raise_undeclared
  end

  def events
    CloudImplementation::raise_undeclared
  end


  ############
  # Keypairs #
  ############

  class Keypair

    def initialize(name, pk_path = nil)
      if pk_path == nil
        @pk_path = ENV["HOME"]+"/.ssh/"+name
      else
        @pk_path = pk_path
      end
    end

    def pk_path
      @pk_path
    end

    # get the a public key of name from the stack
    def get_pub
      CloudImplementation::raise_undeclared
    end

    #public key -> stack
    # (the heart of any create keypair method)
    def send_key(public_key)
      CloudImplementation::raise_undeclared
    end

    def delete
      #use @name
      CloudImplementation::raise_undeclared
    end

  end

  # Support Functions for poll events #

  #returns a lambda that, given some x, returns a unique identifier for x
  def event_id_getter
    CloudImplementation::raise_undeclared
  end

  #returns a lambda that, given some x, returns true if x is a tail_event that
  #indicates polling should terminate
  def poll_terminator(name)
    CloudImplementation::raise_undeclared
  end

  #returns a lambda that, given some x, returns the resource_status for x
  def resource_status
    CloudImplementation::raise_undeclared
  end

  ####################
  # Common Utilities #
  ####################

  # HASHLOADING #

  def supported_format(extension, parsers)
    return parsers.has_key?(extension)
  end

  # This loads a file as directed by parsers and returns the result
  def hashload(filename, parsers)
    extension = File.extname(filename)
    err = "Filename has an unsupported extension: #{filename}"
    raise Exception.new(err) unless supported_format(extension,parsers)

    parser = parsers[extension]
    return parser.call(filename)
  end

  #this loads a sequence of hashes from filenames and merges them together.
  def plural_hashload(filenames, parsers)
    #load and parse files
    result = filenames.inject({}) { |result,filename|
                                result.merge!( hashload(filename,parsers) ) }
    # Replace nil with empty string
    hash = Hash[result.map { |k,v| [k, v == nil ? "" : v] }]
    return hash
  end

  #sort array according to order.
  # :ETC sorts everything not specified according to normal.
  #best for displaying information of particular interest preferrentially at
  #the beginning or end.
  def self.sort_override(array, order)
    pivot_i  = order.find_index(:ETC)
    pre_etc  = order[0...pivot_i]
    post_etc = order[pivot_i+1..-1]

    pre_array = array.select { |x| pre_etc.include? x }
    post_array = array.select { |x| post_etc.include? x }
    etc_array = array.select { |x|
                  not (pre_etc.include? x or post_etc.include? x) }

    pre_array.sort_by! { |x| pre_etc.index x }
    etc_array.sort_by!
    post_array.sort_by! { |x| post_etc.index x }

    ordered_array = pre_array + etc_array + post_array
    return ordered_array
  end
end
OLD_TRIGGER = "OLD"


#######################
# AMAZON WEB SERVICES #
#######################
#
# Most things are handled by the aws_sdk
#
class ThunderAWS < CloudImplementation
  def initialize(thunder_config, options={})
    super(options)

    config_aws(thunder_config)
    @cfm = AWS::CloudFormation.new
    @ec2 = AWS::EC2.new
    @kpc = AWS::EC2::KeyPairCollection.new

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
    rescue AWS::CloudFormation::Errors::AlreadyExistsException
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

      temp = ThunderAWS.new(config)
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

    AWS.config(:region => creds[:region],
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


#######################
# OPENSTACK           #
#######################
# How things are obtained:
#   1) If it's in 'fog', try that.
#   2) Make an API call.
class ThunderOS < CloudImplementation
  def initialize(thunder_config, options={})
    super(options)

    @config = config_os(thunder_config)
    @orch = orch
    @stacks = hash_stacks(@orch.stacks)

    @compute = Fog::Compute.new(@config.merge({:provider => "OpenStack"}))

  end

  #################
  # Native Config #
  #################

  def self.get_native
    {"openstack_auth_url" => ENV["OS_AUTH_URL"],
      "openstack_username" => ENV["OS_USERNAME"],
      "openstack_tenant" => ENV["OS_TENANT_NAME"],
      "openstack_api_key" => ENV["OS_PASSWORD"],
      "openstack_tenant_id" => ENV["OS_TENANT_ID"],
      "openstack_region_name" => ENV["OS_REGION_NAME"],
      "connection_options" => {}
    }
  end

  ##############
  # Manipulate #
  ##############
  def create(name, raw_template, *parameterss)
    template = load_template(raw_template)
    parameters = load_parameters(parameterss)
    filtered_parameters = filter_parameters(parameters, template)


    begin
      @orch.stacks.create({:stack_name => name,
                            :template => template.to_json,
                            :parameters => filtered_parameters})
    rescue Exception => e #idk the duplicate exception yet
      raise e
    end
  end

  def delete(name)
    stack_id = get_stack_id(name)
    @orch.delete_stack(name, stack_id)
  end

  def update(name, template, parameterss)
    #load all the crap
    template = load_template(template, rmt_template=true)
    parameters = load_parameters(parameterss)
    filtered_parameters = filter_parameters(parameters, template)

    #do it
    stack_id = get_stack_id(name)
    @orch.update_stack(stack_id, name,
                       {:stack_name => name,
                         :template => template.to_json,
                         :parameters => filtered_parameters})
  end


  ###########
  # Observe #
  ###########
  def stacks
    @orch.stacks.map { |stak| { :Name   => stak.stack_name,
                                :Status => stak.stack_status,
                                :Reason => stak.stack_status_reason } }
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
    return {
      ".json" => lambda {|r| JSON.parse(File.read(r)) },
      ".rb"   => lambda {|r| JSON.parse( CfnDsl::eval_file_with_extras(r, extras).to_json)},
      "" => lambda { |r| raise Exception.new("Openstack templates must be manually resupplied on update.") }
    }
  end

  def load_template(template, rmt_template = false)
    return hashload(template, template_parsers(rmt_template))
  end

  # Parameters-related #

  def remote_param_default(name)
    stack_id = get_stack_id(name)
    os_outputs(name, stack_id)
  end

  def remote_param_old(long_name)
    ext = File.extname(long_name)
    name = long_name[0 ... -ext.length]
    stack_id = get_stack_id(name)
    os_parameters(name,stack_id).inject({}) { |hash, item|
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
    @stacks[stack_name].id
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

  class Keypair < CloudImplementation::Keypair

    def initialize(name, config, pk_path = nil)
      if pk_path == nil
        super(name)
      else
        super(name, pk_path = pk_path)
      end

      @name = name
      temp = ThunderOS.new(config) #just ripping the cons out of here
      @compute = temp.compute
    end

    def get_pub
      key_pairs = @compute.list_key_pairs.body["keypairs"]
      key_pairs = key_pairs.map { |kp| kp["keypair"] } #flatten

      key_pair = key_pairs.select { |x| x["name"] == @name }

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
      @compute.delete_key_pair(@name)
    end

    #public key -> stack
    # (this is the heart of "create")
    def send_key(public_key)
      @compute.create_key_pair(@name, public_key)
    end
  end

  ###############
  # Connections #
  ###############


  # FOG-RELATED CONNECTION STUFF #
  def config_os(os_vars)
    creds = {}

    creds[:openstack_auth_url] = os_vars["openstack_auth_url"]
    creds[:openstack_username] = os_vars["openstack_username"]
    creds[:openstack_tenant] = os_vars["openstack_tenant"]
    creds[:openstack_api_key] = os_vars["openstack_api_key"]
    creds[:connection_options] = os_vars["connection_options"] || ''

    creds[:connection_options] = {} #JSON.parse(creds[:connection_options]) if creds[:connection_options]
    return creds
  end

  def orch
    return @orch || Fog::Orchestration.new({:provider => 'openstack'}.merge(@config))
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
    api_url = svc_catalog["heat"]["endpoints"][0]["internalURL"]
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

  #####################
  # Steal Connections #
  #####################
  # Because encapsulation is for the weak-minded.
  # ... really, because it's needed for the keypair stuff.

  def compute
    @compute
  end

end
