module Thunder
  module Subcommand
    class Sherpa < Thor
      include Thunder::Connection
      package_name "sherpa"
      include Thor::Actions
      
      #why is it called "sherpa"?
      # 1) srpgo is the free-standing application. The name change avoids
      #     polysemy/overloading of the term. 
      # 2) a sherpa--in the mountain guide sense--guides you up a mountain
      #     up to where cloud formation takes place, to where thunder happens.
      #     This is precisely what this script does, though the mountain is
      #     metaphorical.

      #why not just srpgo(*args)? 
      # This allows for explicit documentation of available commands in a Thor-
      # like way. srpgo(*args) wouldn't exploit Thor's documentation style. 

      desc "create stack_name template parameters* -g srp.yaml",
            "srpgo style create: put template files in a bucket, create stack"
      def create(*args)
        srpgo("create", args)
      end 

      desc "update stack_name template parameters* -g srp.yaml",
            "srpgo style update: put file in a bucket, update stack"
      def update(*args)
        srpgo("update", args)
      end 

      no_commands do
        def srpgo(command, args)
          args = [command] + args
          #stack_name = args[0]
          #template_filename = args[1]
          #parameters = args[2..-1]

          #pardon my indentation
          #I literally copied srpgo right in here, and
          #I don't wanna stretch my window

# This script aids in launching a builder script by
#  1) compiling all of the client and foundation.rb templates into json
#  2) uploading template jsons to a unique-named folder in an s3 bucket
#  3) launching thunder to create or update a named builder stack

# Hard Coded Configuration

# "templates.platform.infochimps" is owned by the "infochimps"
# account, but that it allows write access by the
# "srp1-infochimps" account into the /dev folder. Everything in this
# bucket is currently world readable, so do not put anything secret
# into a template!

bucket_name = "templates.platform.infochimps"

# Also, it is configured to autodelete content from the "/dev"
# directory one day after its creation date. Other folders may hav
# similar rules in the future.

bucket_base_dir = "dev"

# API access to s3 buckets can be a pain. For this one, we HAVE to go through
# us-east-1. Even if you are going to be creating stacks in a different region
# do not change this value unless you have set up your own bucket and you
# know what you are doing.
bucket_region = "us-east-1"

# Where to put generated files
temp_dir = ".upload"

# Name of the paramteter to use to tell the builder stack where to find its client jsons
template_url_parameter = "TemplateUrlBase"


# If any generation parameters are supplied, they must be at the end of the thunder
# command line. These will be passed to cfndsl when we build the clients. Currently these
# must be yaml

#Divide the parameters into generation and non-generation, pivoting around -g

generation_parameters = []
non_generation_parameters = args
generation_parameters = args[ args.index("-g")+1..-1 ] if args.index("-g")
non_generation_parameters = args[ 0...args.index("-g") ] if args.index("-g")

#adds -y before each of generation_parameters
cfndsl_gen_parms = generation_parameters.inject([]) { |a,i| a.push("-y",i) }

# Presently, this script is only designed to pass stuff on to thunder to do the actual
# launch of a builder-style script.

unless system("aws --version > /dev/null") then
  puts "This script requires the aws-cli tools to be installed."
  exit(-1)
end

# Generate unique filename
user = Etc::getpwuid.name
time = Time.now.strftime('%Y%m%dT%H%M%S%z')
uuid = SecureRandom.uuid

uniq=[user,time,uuid].join("-")

updir = FileUtils.mkdir_p( File.join(temp_dir,uniq) )[0]
cldir = FileUtils.mkdir_p( File.join(updir,"clients" ))[0]
fddir = FileUtils.mkdir_p( File.join(updir,"foundation"))[0]

# launch-kickoff home directory
# THIS IS GONNA BE A TRICKY FIX -- add to .thunder config?
# Travis suggested adding this as a "find the launch-kickoff dir"
# utility function somewhere. A good idea.
kickoff_home = File.expand_path('../..', __FILE__)


#run cfndsl for rb files and pipe each to the appropriate JSON file.

Dir.glob("#{kickoff_home}/clients/*.rb") do |infile|
  outfile = File.join(cldir,File.basename(infile,".rb")+".json")
  ok = system "cfndsl #{infile} #{cfndsl_gen_parms.join ' '} > #{outfile}"
  if !ok then
    STDERR.puts "cfndsl failed on #{infile}. stopping."
    exit(1)
  end
end

Dir.glob("#{kickoff_home}/foundation/*foundation*.rb") do |infile|
  outfile = File.join(fddir,File.basename(infile,".rb")+".json")
  ok = system "cfndsl #{infile} #{cfndsl_gen_parms.join ' '} > #{outfile}"
  if !ok then
    STDERR.puts "cfndsl failed on #{infile}. stopping."
    exit(1)
  end
end

#what's being synced here? the cfndsl outputs.
#TODO: use the aws-sdk to to do this?
system "aws --region=#{bucket_region} s3 sync  #{updir} s3://#{bucket_name}/#{bucket_base_dir}/#{uniq}/  --acl=public-read"

#generate a new parameters file that indicates the location of the template_url
parameters = { template_url_parameter => "https://s3.amazonaws.com/#{bucket_name}/#{bucket_base_dir}/#{uniq}" }
params_file_name = File.join(updir,"#{uniq}_parameters.json")
File.open(params_file_name,"w") do |f|
  f.write(parameters.to_json)
end


#assemble parameters filenames for thunder
thunder_parameters = non_generation_parameters
thunder_parameters.push params_file_name
if generation_parameters.length > 0 then
  thunder_parameters.push("-g")
  thunder_parameters += generation_parameters
end

puts "thunder stack " + thunder_parameters.join(" ")
system("thunder stack " + thunder_parameters.join(" "))


      end
    end

    end
  end
end
