def aws
  config = Thunder::Configuration.new.populate!
  aws = Thunder::CloudImplementation::AWS.new config.to_hash
end

Before do
  @aruba_timeout_seconds = 5
end

After('@keypair', '@aws') do
  aws.delete_pubkey 'example'
  FileUtils.rm 'tmp/example' if File.exists? 'tmp/example'
end

Then(/^the keypair "(.*?)" should exist$/) do |name|
  expect(aws.get_pubkey(name)).to_not be_nil
end

