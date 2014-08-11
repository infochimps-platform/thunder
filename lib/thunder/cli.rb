#########################################################################
# Thor + Cloud == Thunder
#   at least version (0.8)
# Dan Simonson, Infochimps, Summer 2014
#
#   Thunder is a Thor-implemented set of tools for cloud formation.
#
#   This is the application layer of thunder. For details on how the
#   connections to OpenStack and AWS are handled, see/require
#   'thunder'.
#
#
#########################################################################

class ConThor < Thor
  # This class deals with cross cutting concerns of loading up the thunder
  # configuration files, and getting back end connections to aws or
  # openstack, depending on the environment.

  # Note that the class "SubThor" adapts the necessary methods for the
  # con and load_config methods to work (it has to go through parent_options)

  no_commands do
    ###################
    # Thor Meta-stuff #
    ###################
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

      config_filename = File.expand_path(config_file )
      conf = YAML.load(File.open(config_filename).read)
      config = conf[ config_section ]

      config.inject({}) { |hash,(k,v)| hash[k] = v.is_a?(String) ? v.strip : v; hash }
    end
  end
end

class Stack < ConThor
  package_name "stack"
  include Thor::Actions
  THUNDIR = ENV["HOME"]+"/.thunder/"
  CONFIG_PATH = THUNDIR+"config"

  # Global Options
  class_option :config_file,
               :aliases => "-c",
               :type => :string,
               :desc => "Thunder configuration file.",
               :default => CONFIG_PATH
  class_option :config_file_section,
               :aliases => "-S",
               :type => :string,
               :desc => "Thunder configuration file section.",
               :default => "default"
  class_option :openstack,
               :aliases => "-o",
               :type => :boolean,
               :desc => "Use OpenStack."
  class_option :aws,
               :aliases => "-a",
               :type => :boolean,
               :desc => "Use AWS."



  desc "config", "Configure default settings for running thunder."
  def config
    say "Thunder Config"
    cfg_hash = {}
    cfg_hash["flavor"] = ask("Stack flavor: ",
                                :limited_to => ["aws","openstack"])

    say "3600 seconds per hour, 86400 per day. (YOU HAVE TO ENTER A VALUE)"
    cfg_hash["poll_events_timeout"] = Integer ask("Poll events timeout (in seconds):")
    puts "If you don't know (or don't care) the values, leave them blank."
    puts "If you want to use the old value, leave it blank."
    aws_vars = ["aws_access_key_id",
                "aws_secret_access_key",
                "region"]
    os_vars = ["openstack_auth_url",
               "openstack_username",
               "openstack_tenant",
               "openstack_api_key",
               "connection_options"]

    (os_vars + aws_vars).each do |s|
      cfg_hash[s] = ask(s+": ")
      if cfg_hash[s] == ""
        cfg_hash.delete(s)
      end
    end

    #recover values that haven't been over-written
    old_hash = load_config rescue {}
    cfg_hash = old_hash.merge(cfg_hash)

    #add place-holders for unspecified values
    #(this is an initialization step, more or less, so they're present in the
    # yaml)

    fillers = (aws_vars+os_vars).select { |k| not cfg_hash.key?(k) }
    fillers = fillers.inject({}) { |r,k| r[k]="";r }
    cfg_hash.merge! fillers

    #default_config_group--later, for choosing amongst multiple configs
    # for a given flavor--e.g. within ~/.aws/config
    #config_name -- later, for setting up simultaneous configs
    write_config(cfg_hash)
    say "Done. Further changes can be made at ~/.thunder/config"
  end

  @default_config = {"flavor" => "aws",
                     "poll_events_timeout" => 3600} #for reverse compatability

  desc "config_import flavor", "Import config settings from native sources if they exist. flavor is either aws or openstack."

  def config_import(flavor)
    old_hash = load_config rescue {}

    default = old_hash
    default["flavor"] = flavor

    config = {"aws" => Thunder::AWS::get_native,
              "openstack" => Thunder::Openstack::get_native}[flavor]

    if config == nil
      puts "Flavor unrecognized, or no native data found."
    else
      puts "Config found. Importing..."
      config.each do |k,v|
        #get rid of garbage
        if v == "" or v == nil
          config.delete(k)
        end

      end
      default.merge!(config)
    end
    write_config(default)
  end

  no_commands do
    def write_config(cfg_hash, config_filename = nil)
      config_filename ||= config_options[:config_file]
      output = {"default" => cfg_hash}

      thundir = File.dirname(File.expand_path(config_filename))

      if not File.directory? thundir
        Dir.mkdir(thundir)
      end

      File.open(config_filename, "w") do |f|
        f.write(output.to_yaml)
      end
    end

  end

  ##########
  # Create #
  ##########
  desc "create name template *parameters", "Create a stack.\
        Parameters without a stackname ~> existing stack to retrieve from."
  method_option :generation_parameters,
                :aliases => "-g",
                :type => :array,
                :description => "File containing generation parameters."
  def create(name, raw_template, *parameterss)
    con.create(name, raw_template, *parameterss)
  end


  ##########
  # Update #
  ##########
  desc "update name template *parameters", "Update a stack."
  method_option :reuse_template,
                :aliases => "-r",
                :type => :boolean,
                :desc => "Reuse existing template. Usage: update -r name *parameters"
  method_option :default_params,
                :aliases => "-d",
                :type => :boolean,
                :desc => "Restore default/ignore previously set parameter values."
  method_option :generation_parameters,
                :aliases => "-g",
                :type => :array,
                :description => "File containing generation parameters."
  def update(*args)
    #extract args
    if options[:reuse_template]
      name = args[0]
      template = name #needed for filtering
      parameterss = args[1..-1]
    else
      name = args[0]
      template = args[1]
      parameterss = args[2..-1]
    end

    #if set, don't merge with previously set params
    defparm = options[:default_params] ? [] : [name+".OLD"]
    parameterss = defparm + parameterss

    con.update(name,template, parameterss)
  end

  ##############
  # Parameters #
  ##############
  desc "parameters template", "Get default parameters for a stack."

  method_option :generation_parameters,
                :aliases => "-g",
                :type => :array,
                :description => "File containing generation parameters."
  def parameters(template)
    template = con.load_template(args[0], rmt_template=true)

    puts "# Default parameter values for #{args[0]}"
    puts

    template["Parameters"].each do |name, value|
      # Turn the description into a comment
      width = 80
      if value["Description"] then
        comment = value["Description"].scan(/\S.{0,#{width}}\S(?=\s|$)|\S+/).join("\n")
        puts comment.gsub(/^/,"# ")
      end
      # Build something like   name: Default
      # for the rest of the parameter
      puts({ name => value["Default"]}.to_yaml.sub(/^---\n/,''))
      puts
    end

  end


  ##########
  # Delete #
  ##########
  desc "delete name", "Bye-bye, stack."
  def delete(name)
    con.delete(name)
  end


  ###################
  # Dumping Methods #
  ###################
  # These are things that dump out stuff in one form or another.
  # I tried to abstract these but ran into issues. If I had more time
  # to mess around with Ruby, I could make these a lot more streamlined/
  # less copy-pasted.

  desc "stacks", "List all stacks."
  method_option :json,
                :aliases => "-j",
                :type => :boolean,
                :desc => "Dump as JSON."
  def stacks
    table = con.stacks

    if options[:json]
      puts table.to_json
    else
      Formatador.display_compact_table(table, [:Name,:Status,:Reason] )
    end
  end


  desc "outputs name", "Get the outputs from stack 'name.'"
  method_option :json,
                :aliases => "-j",
                :type => :boolean,
                :desc => "Dump as JSON."
  def outputs(name)
    table = con.outputs(name)

    if options[:json]
      puts table.to_json
    else
      Formatador.display_compact_table(table)
    end
  end


  desc "events name", "Get the events from stack 'name.'"
  method_option :verbose,
                :aliases => "-v",
                :type => :boolean,
                :desc => "A bit of garbage for your viewing pleasure."
  method_option :json,
                :aliases => "-j",
                :type => :boolean,
                :desc => "Dump as JSON."
  def events(name)
    events = con.events(name)
    con.display_events(events, options)
  end


  class SubThor < ConThor
    no_commands do
      def config_options
        return parent_options
      end
    end
  end

  ###########
  # Pollers #
  ###########

  class Poll < SubThor
    POLL_SLEEP = 15
    SUCCESS = 0
    FAILURE = 1

    no_commands do
      def timeout
        @timeout ||= load_config["poll_events_timeout"] #in seconds
      end
    end

    desc "poll events name", "Poll a stack's events. c.f. poll-stack-events"
    method_option :event_bell,
          :aliases => "-b",
          :type => :boolean,
          :desc => "Print bell/alert when a new event occurs."
    method_option :terminal_bell,
          :aliases => "-B",
          :type => :boolean,
          :desc => "Print bell/alert when termination reached."
    method_option :delete,
          :aliases => "-d",
          :type => :boolean,
          :desc => "Count as SUCCESS if stack name is gone."
    def events(name)
      start = Time.now
      offset = 0
      seen_before = []

      while (Time.now - start) < timeout

        begin
          events = con.events(name)

          #these are all lambdas for doing certain operations on events
          get_id = con.event_id_getter
          terminate = con.poll_terminator(name)
          resource_status = con.resource_status

        # This should rescue for stack-not-found errors
        rescue
          if options[:delete]
            bell
            exit SUCCESS
          else
            say "Couldn't access stack #{name}."
            exit FAILURE
          end
        end

        #check for previously seen events: filter and save any found
        events = events.select{|x| not seen_before.include? get_id.call(x) }
        seen_before.concat(events.map { |x| get_id.call(x) })

        if events != []
          bell
          con.display_events(events,options)

          tail_event = events[-1]
          if terminate.call(tail_event)
            case resource_status.call(tail_event)
              when 'CREATE_COMPLETE'
                bell
                exit SUCCESS
              when 'CREATE_FAILED'
                bell
                exit FAILURE
              when 'UPDATE_COMPLETE'
                bell
                exit SUCCESS
              when 'UPDATE_FAILED'
                bell
                exit FAILURE
              when 'ROLLBACK_COMPLETE'
                bell
                exit FAILURE
              when 'DELETE_COMPLETE'
                bell
                exit SUCCESS
              else
            end #case
          end #if tail_event
        end #if events
      offset = events.length
      sleep POLL_SLEEP
      end #while
      say "While loop exit -- time out?"
      bell
     end

    no_commands do

      def bell
        STDERR.puts "\a" if options[:terminal_bell]
      end

    end

  end

  desc "poll [COMMAND...]", "Poll a stack."
  subcommand "poll", Poll

  ############
  # Key Pair #
  ############
  class Keypair < SubThor
    package_name "keypair"
    include Thor::Actions

    no_commands do
      def private_key_path(name)
        return ENV["HOME"]+"/.ssh/"+name
      end

      def load_private(path)
        return SSHKey.new(File.read(path))
      end

      def get_kp_con(kp_name)
        config = load_config
        if options[:openstack]
          kp_con = Thunder::Openstack::Keypair.new(kp_name, config)
        else
          kp_con = Thunder::AWS::Keypair.new(kp_name, config)
        end
      end
    end

    desc "keypair create name", "Create a keypair (if possible)."
    long_desc <<-LONGDESC
  thunder keypair create name

  Looks for a public key in EC2 named "name" and a private key ~/.ssh/name
  Does a number of things, depending on the state of things.

  if aws has a public key and there's a private key:
    compare fingerprints

  if aws has a public key and there's NO private key:
    yell at the user

  if aws has NO public key and there's a private key:
    use the private key in ~/.ssh/name

  if aws has NO public key and there's NO private key:
    create a new private key, use it, and save it.

  LONGDESC
    def create(name)
      kp_con = get_kp_con(name)

      aws = kp_con.get_pub != nil
      local = File.exists? kp_con.pk_path

      pk_path = kp_con.pk_path

      if not aws
        if local
          say "Using "
          say "existing private key ", color = :on_blue
          say "at: "
          say pk_path
          keypair = load_private(pk_path)

        else
          say "Generating new private and public keys called "+name

          keypair = SSHKey.generate

          #save the private key locally.
          File.open(pk_path, "wb") do |f|
            f.write(keypair.private_key)
          end #pk_path
        end #local

        kp_con.send_key(keypair.ssh_public_key)

      else
        if local
          say "Key already exists. ", color = :on_blue
          #say "Checking finger prints..."
          #fingerprints(name)
        else
          say "The public key was found on the cloud, but the private "
          say "key was not found locally."
        end
      end

    end

    desc "keypair delete name", "Delete a keypair"
    def delete(name)
      kp_con = get_kp_con(name)
      keypair = kp_con.get_pub

      if keypair == nil
        say "No key has that name."
      else
        kp_con.delete
        say "Delete successful."
      end

      pk_path = kp_con.pk_path
      if pk_path != nil and File.exists? pk_path
        say "(Local copy of private key still exists.)"
      end
    end

  end

  desc "keypair [COMMAND...]", "Do stuff with keypairs."
  subcommand "keypair", Keypair

end


