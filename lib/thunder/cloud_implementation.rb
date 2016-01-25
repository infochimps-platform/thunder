# abstract connection module:
#   - allows sharing of common methods (what few there may be)
module Thunder
  module CloudImplementation

    # Constructor #
    def initialize(options)
      @options = options

      # This builds up a list of extra parameters to pass to cfndsl.
      sym_lookup = { ".yaml" => :yaml, ".json" => :json }
      @template_generation_extras = (options[:generation_parameters] || []).map {|f| [sym_lookup[File.extname(f)], f] }
      bad_generators = @template_generation_extras.select {|f| !f[0] }.map {|f| f[1]}
      throw Exception.new("Unknown generation parameter file types: #{bad_generators.join ', '}") if bad_generators.length > 0

    end

    ####################
    # Common Utilities #
    ####################

    # HASHLOADING #

    def supported_format(extension, parsers)
      parsers.key? extension
    end

    # Get a string that we can create a stack with from a parsed template
    def get_template_text(template)
      if template.key? '_thunder_url'
        return template['_thunder_url']
      else
        return template.to_json
      end
    end

    # This loads a file as directed by parsers and returns the result
    def hashload(filename, parsers)
      extension = File.extname filename
      msg = <<-MSG.gsub(/^ {8}/, '')
        Filename #{filename} appears to have an unsupported extension: #{extension}.
        I bet you're wondering 'what do you mean, that IS supported.' If that's the case,
        MAKE SURE YOU REMEMBERED TO INCLUDE THE STACK NAME IN YOUR COMMAND: ALL YOUR PARAMS ARE GETTING OFFSET,
        AND THIS IS THE EIGHTH TIME I'VE FORGOTTEN THIS AND REMEMBERED THE ROOT CAUSE. (RageException)
      MSG
      fail Exception, msg unless supported_format(extension, parsers)
      parser = parsers[extension]
      parser.call(filename).tap{ |hsh| hsh['_thunder_url'] = filename if filename =~ %r{^https?://} }
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
end
