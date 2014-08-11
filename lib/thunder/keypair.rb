module Thunder
  class CloudImplementation
    class Keypair

      def initialize(name, pk_path = nil)
        if pk_path == nil
          @pk_path = ENV["HOME"]+"/.ssh/"+name
        else
          @pk_path = pk_path
        end
      end

      def pk_path
        @pk_path
      end

      # get the a public key of name from the stack
      def get_pub
        CloudImplementation::raise_undeclared
      end

      #public key -> stack
      # (the heart of any create keypair method)
      def send_key(public_key)
        CloudImplementation::raise_undeclared
      end

      def delete
        #use @name
        CloudImplementation::raise_undeclared
      end

    end
  end
end
