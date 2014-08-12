module Thunder
  module Cli
    class Stack < Thunder::Cli::Connection
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

      desc "list", "List all stacks."
      method_option :json,
      :aliases => "-j",
      :type => :boolean,
      :desc => "Dump as JSON."
      def list
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

    end
  end
end
