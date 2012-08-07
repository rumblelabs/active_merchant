require 'test_helper'

class GoCardlessNotificationTest < Test::Unit::TestCase
  include ActiveMerchant::Billing::Integrations

  def setup
    @notification = GoCardless::Notification.new(body)
  end

  def test_accessors
    assert_equal @notification.type, 'bill'
    assert_equal @notification.action, 'created'
    assert_equal @notification.resources.size, 1
  end

  def test_resources
    assert_equal @notification.resources.first['id'], '45756765'
  end

  private

  def body
    '{
      "payload": {
        "bills": [
          {
            "id": "45756765",
            "status": "pending",
            "uri": "https://sandbox.gocardless.com/api/v1/bills/45756765",
            "amount": "20.0",
            "amount_minus_fees": "19.8"
          }
        ],
        "resource_type": "bill",
        "action": "created",
        "signature": "130bb64f8835eef4a9b2a8734967cc2d0a4f4956ce6604919dc8a6c25925f9d5"
      }
    }'
  end
end
