require 'aruba'
require 'aruba/api'

if ENV['THUNDER_COV']
  require 'simplecov'
  SimpleCov.start do
    add_group 'Specs',   'spec/'
    add_group 'Library', 'lib/'
  end
end

require 'thunder'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each{ |f| require f }

RSpec.configure do
  include Aruba::Api
end
