module Thunder
  module Subcommand
    class Keypair < Thor
      include Thunder::Connection
      package_name "keypair"
      def self.banner(command, namespace = nil, subcommand = false)
        "#{basename} #{@package_name} #{command.usage}"
      end

      include Thor::Actions

      no_commands do
        def config_options
          parent_options
        end

        def private_key_path name
          File.join(ENV['HOME'], '.ssh', name)
        end

        def load_private path
          SSHKey.new(File.read path)
        end
      end

      desc 'create name', 'Create a keypair (if possible).'
      long_desc <<-LONGDESC.gsub(/^ {8}/, '')
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
      def create name
        pk_path = private_key_path name
        local = File.exists? pk_path
        unless con.get_pubkey(name)
          if local
            say "Using "
            say "existing private key ", color = :on_blue
            say "at: "
            say pk_path
            keypair = load_private(pk_path)
          else
            say "Generating new private and public keys called #{name}"
            keypair = SSHKey.generate
            # save the private key locally.
            File.open(pk_path, 'wb'){ |f| f.write keypair.private_key }
          end
          con.send_key(name, keypair.ssh_public_key)
        else
          if local
            say "Key already exists. ", color = :on_blue
          else
            say "The public key was found on the cloud, but the private "
            say "key was not found locally."
            say "No action taken"
          end
        end
      end

      desc "delete name", "Delete a keypair"
      def delete name
        keypair = con.get_pubkey name

        if keypair == nil
          say "No key has that name."
        else
          con.delete_pubkey name
          say "Delete successful."
        end

        say "(Local copy of private key still exists.)" if File.exists? private_key_path(name).to_s
      end

    end
  end
end
