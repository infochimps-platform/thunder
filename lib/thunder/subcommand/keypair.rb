module Thunder
  module Subcommand
    class Keypair < Thor
      include Thunder::Connection
      package_name "keypair"
      include Thor::Actions

      no_commands do
        def config_options
          return parent_options
        end

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
  end
end
