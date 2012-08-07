require 'gocardless'
require 'test_helper'

require 'rack'

class Receiver

  def call(env)
    request = Rack::Request.new(env)
    @callback.call(request)
    [200, {}, ['']]
  end

  def self.run
    server = self.new
    
    server.wait do |request|
      yield request
      server.kill
    end

    server.run
  end

  def run
    @thread = Thread.new do
      Rack::Handler::Mongrel.run(self, :Port => 9292)
    end

    @thread.join
  end

  def kill
    @thread.kill
  end

  def wait(&block)
    @callback = block.to_proc
  end

end

class RemoteGoCardlessIntegrationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    ::GoCardless.environment = :sandbox
    GoCardless.configure fixtures(:go_cardless)
  end

  def test_subscription_url
    url = GoCardless.subscription_url(:amount => 30, :interval_length => 1, :interval_unit => :month, :redirect_uri => 'http://localhost:9292/test')
    
    puts "Subscribe at: #{url}"

    Receiver.run do |request|
      puts request.params
      assert GoCardless.return(request.params).confirm!
    end
  end

end