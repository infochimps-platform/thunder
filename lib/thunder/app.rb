module Thunder
  class App < Thor
    include Thunder::Connection

    class_option :config_section, aliases: '-S', type: :string,  desc: 'Thunder configuration file section.'
    class_option :config_file,    aliases: '-c', type: :string,  desc: 'Thunder configuration file.'
    class_option :openstack,      aliases: '-o', type: :boolean, desc: 'Use OpenStack.'
    class_option :aws,            aliases: '-a', type: :boolean, desc: 'Use AWS.'

    desc 'config', 'Configure default settings for running thunder.'
    def config
      say 'Thunder Config'
      say "If you don't know (or don't care) the values, leave them blank."
      say 'If you want to use the old value, leave it blank.'
      user_values = {}
      user_values[:flavor] = ask('Stack flavor: ', limited_to: %w(aws openstack), default: 'aws')
      user_values[:poll_events_timeout] = Integer ask('Poll events timeout (in seconds):')
      configuration.all_options.each{ |opt| user_values[opt] = ask("#{opt}: ") }
      configuration.update user_values.select{ |_, val| val.to_s =~ /\w+/ }
      configuration.write_to_disk
      say "Done. Further changes can be made at #{configuration.location}"
    end

    desc 'config_import flavor', 'Import config settings from native sources if they exist [aws, openstack].'
    def config_import(flavor, location = nil)
      configuration.update(flavor: flavor)
      native = case flavor
               when 'aws'       then Thunder::CloudImplementation::AWS.native_config(location)
               when 'openstack' then Thunder::CloudImplementation::Openstack.native_config(location)
               else
                 abort 'Flavor unrecognized'
               end
      configuration.update native.select{ |_, val| val.to_s =~ /\w+/ }
      configuration.write_to_disk
      say "Config updated with native #{flavor}"
    end

    desc 'info', 'Display info about currently configured cloud connection. Optional [STACK]'
    def info(stack_name = nil)
      implementation_selector == :openstack ? os_info : aws_info
      if stack_name
        exist_info = con.present_stacks.find{ |s| s[:Name] == stack_name } ? 'exists' : 'does not exist'
        say "Stack: '#{stack_name}' #{exist_info}"
      end
    end

    no_commands do
      def aws_info
        say "Account Alias: #{con.iam.account_alias}"
        say "Account Id: #{con.account_id}"
        region = configuration[:region]
        say "Region: #{region} (#{con.region_map[region]})"
      end

      def os_info
        #TODO
      end
    end

    desc 'stack [COMMAND]', 'Stack actions'
    subcommand 'stack', Subcommand::Stack

    desc 'keypair [COMMAND]', 'Do stuff with keypairs.'
    subcommand 'keypair', Subcommand::Keypair

    desc 'poll [COMMAND]', 'Poll a stack.'
    subcommand 'poll', Subcommand::Poll

    desc 'sherpa [COMMAND]', 'aka srpgo: Upload to buckets and run thunder.'
    subcommand 'sherpa', Subcommand::Sherpa

    desc 'remote_file [COMMAND]', 'persist a file for remote access later'
    subcommand 'remote_file', Subcommand::RemoteFile
  end
end
