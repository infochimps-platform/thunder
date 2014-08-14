module Thunder
  module Cli
    class App < Thor
      include Thunder::Cli::Connection
      package_name "app"
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

      desc "stack [COMMAND...]", "Stack actions"
      subcommand "stack", Stack

      desc "keypair [COMMAND...]", "Do stuff with keypairs."
      subcommand "keypair", Keypair

      desc "poll [COMMAND...]", "Poll a stack."
      subcommand "poll", Poll

    end
  end
end
