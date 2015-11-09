module Thunder
  module Subcommand
    class Stack < Thor
      include Thunder::Connection

      package_name "stack"
      include Thor::Actions

      no_commands do
        def config_options
          return parent_options
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
      # Status #
      ##########
      desc "status name","display the status for the named stack"
      def status(name)
        begin
          puts con.status(name)
        rescue
          puts "UNKNOWN"
        end
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
      desc "parameters stack template parameterss*", "Get default parameters for a stack template and merge additional params."

      method_option :generation_parameters,
      :aliases => "-g",
      :type => :array,
      :description => "File containing generation parameters."
      def parameters(*args)
        template_name = args[0]
        parameterss = args[1..-1]
        unfiltered_parameters = con.load_parameters(parameterss)

        puts "# Default parameter values for #{args[0]}"
        puts

        template = con.load_template(template_name, rmt_template=true)
        template["Parameters"].each do |name, value|
          # Turn the description into a comment
          width = 80
          if value["Description"] then
            comment = value["Description"].scan(/\S.{0,#{width}}\S(?=\s|$)|\S+/).join("\n")
            puts comment.gsub(/^/,"# ")
          end
          # Build something like   name: Default
          # for the rest of the parameter
          default_parm_value = { name => value["Default"]}.to_yaml.sub(/^---\n/,'')
          if unfiltered_parameters.has_key?(name) then
            puts("# Stack Default value")
            puts( default_parm_value.gsub(/^/,"# ") )
            puts( { name => unfiltered_parameters[name]}.to_yaml.sub(/^---\n/,''))
          else
            puts( default_parm_value )
          end
          puts
        end

        extra_parameters = unfiltered_parameters.keys - template["Parameters"].keys
        unless extra_parameters.empty? then
          puts
          puts "# Extra Parameters"
          puts "#  These paramers are not included in the template, but for some reason "
          puts "#  were in the paramters files supplied with the generation of this"
          puts "#  config file."
          extra_parameters.each do |name|
            puts( { name => unfiltered_parameters[name]}.to_yaml.sub(/^---\n/,''))
          end
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

      desc "list", "List all stacks."
      method_option :json,
      :aliases => "-j",
      :type => :boolean,
      :desc => "Dump as JSON."
      def list
        table = con.present_stacks

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

    end
  end
end
