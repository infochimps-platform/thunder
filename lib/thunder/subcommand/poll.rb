module Thunder
  module Subcommand
    class Poll < Thor
      include Thunder::Connection

      POLL_SLEEP = 15
      SUCCESS = 0
      FAILURE = 1

      no_commands do

        def config_options
          return parent_options
        end

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
  end
end
