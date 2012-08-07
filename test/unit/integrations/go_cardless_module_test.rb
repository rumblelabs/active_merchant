require 'test_helper'

class GoCardlessModuleTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations
  
  def test_notification_method
    assert_instance_of GoCardless::Notification, GoCardless.notification('{ "payload": {} }')
  end
end
