require 'test_helper'

class GoCardlessReturnTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def test_accessors
    assert_equal subscription_return.id, '054MA09QH3'
    assert_equal subscription_return.type, 'subscription'
  end
  
  private

  def subscription_return
    GoCardless::Return.new("resource_id=054MA09QH3&resource_type=subscription")
  end

end
