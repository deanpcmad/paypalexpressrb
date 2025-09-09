require 'simplecov'

SimpleCov.start do
  add_filter 'spec'
end

require 'paypal'
require 'rspec'
require 'rspec/its'
require 'fakeweb'
require 'helpers/fake_response_helper'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  
  RSpec::Expectations.configuration.on_potential_false_positives = :nothing
  
  config.before do
    Paypal.logger = double("logger")
  end
  config.after do
    FakeWeb.clean_registry
  end
end

def sandbox_mode(&block)
  Paypal.sandbox!
  yield
ensure
  Paypal.sandbox = false
end