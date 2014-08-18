module Thunder::Subcommand
  class RemoteFile < Thor
    include Thunder::Connection

    package_name 'remote_file'
    def self.banner(command, namespace = nil, subcommand = false)
      "#{basename} #{@package_name} #{command.usage}"
    end

    desc 'persist [STACK] [FILE]', 'Save a remote file'
    method_option :key_path, aliases: '-k', desc: "Persist file to an alternate path. Default is 'filename'"
    def persist(stack_name, fname)
      say "Persisting remote file #{fname}"
      url = con.persist_remote_file(filename: fname, stack: stack_name, key: options[:key_path])
      say "Remote file stored successfully at #{url}"
    end

    desc 'retrieve [STACK] [FILE]', 'Download a remote file'
    method_option :directory, aliases: '-d', desc: "Directory to save file locally. Default '#{Dir.pwd}'"
    def retrieve(stack_name, key)
      local_file = File.join(options[:directory] || Dir.pwd, File.basename(key))
      puts "Retrieving remote file #{key} and copying to #{local_file}"
      con.retrieve_remote_file(key: key, stack: stack_name, filename: local_file)
    end
  end
end
