require 'thunder'
require 'thunder/cli'
require 'thunder/cli/app'

require 'aruba'
require 'aruba/api'

RSpec.configure do |rspec|
  include Aruba::Api
end
