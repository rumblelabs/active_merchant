require 'test_helper'

class RemoteRealexTest < Test::Unit::TestCase

  def setup
    @gateway = RealexGateway.new(fixtures(:realex))

    # Replace the card numbers with the test account numbers from Realex
    @visa            = card_fixtures(:realex_visa)
    @visa_declined   = card_fixtures(:realex_visa_declined)
    @visa_referral_b = card_fixtures(:realex_visa_referral_b)
    @visa_referral_a = card_fixtures(:realex_visa_referral_a)
    @visa_coms_error = card_fixtures(:realex_visa_coms_error)

    @mastercard            = card_fixtures(:realex_mastercard)
    @mastercard_declined   = card_fixtures(:realex_mastercard_declined)
    @mastercard_referral_b = card_fixtures(:realex_mastercard_referral_b)
    @mastercard_referral_a = card_fixtures(:realex_mastercard_referral_a)
    @mastercard_coms_error = card_fixtures(:realex_mastercard_coms_error)

    @amount = 10000
  end

  def card_fixtures(name)
    credit_card(nil, fixtures(name))
  end

  def test_realex_purchase
    [ @visa, @mastercard ].each do |card|

      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex Purchase',
        :billing_address => {
          :zip => '90210',
          :country => 'US'
        }
      )
      assert_not_nil response
      assert_success response
      assert response.test?
      assert response.authorization.length > 0
      assert_equal "Successful", response.message
    end
  end

  def test_realex_purchase_with_invalid_login
    gateway = RealexGateway.new(
      :login => 'invalid',
      :password => 'invalid'
    )
    response = gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Invalid login test'
    )

    assert_not_nil response
    assert_failure response

    assert_equal '504', response.params['result']
    assert_equal "There is no such merchant id. Please contact realex payments if you continue to experience this problem.", response.message
  end

  def test_realex_purchase_with_invalid_account
    response = RealexGateway.new(fixtures(:realex_with_invalid_account)).purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex purchase with invalid acocunt'
    )

    assert_not_nil response
    assert_failure response

    assert_equal '506', response.params['result']
    assert_equal "There is no such merchant account. Please contact realex payments if you continue to experience this problem.", response.message
  end

  def test_realex_purchase_declined

    [ @visa_declined, @mastercard_declined ].each do |card|

      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex purchase declined'
      )
      assert_not_nil response
      assert_failure response

      assert_equal '101', response.params['result']
      assert_equal response.params['message'], response.message
    end

  end

  def test_realex_purchase_referral_b
    [ @visa_referral_b, @mastercard_referral_b ].each do |card|

      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex Referral B'
      )
      assert_not_nil response
      assert_failure response
      assert response.test?
      assert_equal '102', response.params['result']
      assert_equal RealexGateway::DECLINED, response.message
    end
  end

  def test_realex_purchase_referral_a
    [ @visa_referral_a, @mastercard_referral_a ].each do |card|

      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex Rqeferral A'
      )
      assert_not_nil response
      assert_failure response
      assert_equal '103', response.params['result']
      assert_equal RealexGateway::DECLINED, response.message
    end

  end

  def test_realex_purchase_coms_error

    [ @visa_coms_error, @mastercard_coms_error ].each do |card|

      response = @gateway.purchase(@amount, card,
        :order_id => generate_unique_id,
        :description => 'Test Realex coms error'
      )

      assert_not_nil response
      assert_failure response
      
      assert_equal '200', response.params['result']
      assert_equal RealexGateway::BANK_ERROR, response.message
    end

  end

  def test_realex_ccn_error
    @visa.number = '5'

    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex ccn error'
    )
    assert_not_nil response
    assert_failure response

    assert_equal '508', response.params['result']
    assert_match(/invalid/i, response.message)
  end

  def test_realex_expiry_month_error
    @visa.month = 13

    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex expiry month error'
    )
    assert_not_nil response
    assert_failure response

    assert_equal '509', response.params['result']
    assert_equal "Expiry date invalid", response.message
  end

  def test_realex_expiry_year_error
    @visa.year = 2005

    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex expiry year error'
    )
    assert_not_nil response
    assert_failure response

    assert_equal '509', response.params['result']
    assert_equal "Expiry date invalid", response.message
  end

  def test_invalid_credit_card_name
    @visa.first_name = ""
    @visa.last_name = ""

    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'test_chname_error'
    )
    assert_not_nil response
    assert_failure response

    assert_equal '502', response.params['result']
    assert_match(/mandatory field not present/i, response.message)
  end

  def test_cvn
    @visa_cvn = @visa.clone
    @visa_cvn.verification_value = "111"
    response = @gateway.purchase(@amount, @visa_cvn,
      :order_id => generate_unique_id,
      :description => 'test_cvn'
    )
    assert_not_nil response
    assert_success response
    assert response.authorization.length > 0
  end

  def test_customer_number
    response = @gateway.purchase(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'test_cust_num',
      :customer => 'my customer id'
    )
    assert_not_nil response
    assert_success response
    assert response.authorization.length > 0
  end

  def test_realex_authorize
    response = @gateway.authorize(@amount, @visa,
      :order_id => generate_unique_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )

    assert_not_nil response
    assert_success response
    assert response.test?
    assert response.authorization.length > 0
    assert_equal 'Successful', response.message
  end

  def test_realex_authorize_then_capture
    order_id = generate_unique_id

    auth_response = @gateway.authorize(@amount, @visa,
      :order_id => order_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )

    capture_response = @gateway.capture(@amount, auth_response.authorization)

    assert_not_nil capture_response
    assert_success capture_response
    assert capture_response.test?
    assert capture_response.authorization.length > 0
    assert_equal 'Successful', capture_response.message
    assert_match(/Settled Successfully/, capture_response.params['message'])
  end

  def test_realex_purchase_then_void
    order_id = generate_unique_id

    purchase_response = @gateway.purchase(@amount, @visa,
      :order_id => order_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )

    void_response = @gateway.void(purchase_response.authorization)

    assert_not_nil void_response
    assert_success void_response
    assert void_response.test?
    assert void_response.authorization.length > 0
    assert_equal 'Successful', void_response.message
    assert_match(/Voided Successfully/, void_response.params['message'])
  end

  def test_realex_purchase_then_refund
    order_id = generate_unique_id

    gateway_with_refund_password = RealexGateway.new(fixtures(:realex_with_rebate_secret))

    purchase_response = gateway_with_refund_password.purchase(@amount, @visa,
      :order_id => order_id,
      :description => 'Test Realex Purchase',
      :billing_address => {
        :zip => '90210',
        :country => 'US'
      }
    )

    rebate_response = gateway_with_refund_password.refund(@amount, purchase_response.authorization)

    assert_not_nil rebate_response
    assert_success rebate_response
    assert rebate_response.test?
    assert rebate_response.authorization.length > 0
    assert_equal 'Successful', rebate_response.message
  end

  def test_realex_response_body
    response = @gateway.authorize(@amount, @visa, :order_id => generate_unique_id)
    assert_not_nil response.body
  end


  # response timestamp=\"20100303191232\">\r\n<merchantid>exoftwaretest</merchantid>\r\n<account>internet</account>\r\n<orderid>edeac18e066b7208bbdec24c105c17e1</orderid>\r\n<result>00</result>\r\n<message>Successful</message>\r\n<pasref>69deeba5cc294cbba3e3becc016fd3ed</pasref>\r\n<authcode></authcode>\r\n<batchid></batchid>\r\n<timetaken>0</timetaken>\r\n<processingtimetaken></processingtimetaken>\r\n<md5hash>37f71f37cb3a7eb2e138f46d6fe9cbcb</md5hash>\r\n<sha1hash>1aa79d2d8621c8d2e4c80a752c19c75f717ff8b7</sha1hash>\r\n</response>\r\n", @authorization=nil, @success=true>

  def test_realex_store_user
    options = {
      :order_id => generate_unique_id,
      :user => {
        :id => generate_unique_id,
        :first_name => 'John',
        :last_name => 'Smith'
      }
    }
    response = @gateway.store_user(options)
    
    assert_not_nil response
    assert_success response
    assert_equal 'Successful', response.message   
  end

  def test_realex_store_card
    options = {
      :order_id => generate_unique_id,
      :user => {
        :id => generate_unique_id,
        :first_name => 'John',
        :last_name => 'Smith'
      }
    }
    response = @gateway.store_user(options)
    
    options.merge!(:order_id => generate_unique_id)
    store_card_response = @gateway.store(@visa, options)

    assert_not_nil store_card_response
    assert_success store_card_response
    assert_equal 'Successful', store_card_response.message
  end

  def test_realex_receipt_in
    options = {
      :order_id => generate_unique_id,
      :user => {
        :id => generate_unique_id,
        :first_name => 'John',
        :last_name => 'Smith'
      }
    }
    response = @gateway.store_user(options)
    
    options.merge!(:order_id => generate_unique_id, :payment_method => 'visa01')
    store_card_response = @gateway.store(@visa, options)

    options.merge!({
      :order_id => generate_unique_id,
      :payment_method => 'visa01'
    })
    receipt_in_response = @gateway.recurring(@amount, @visa, options)

    assert_not_nil receipt_in_response
    assert_success receipt_in_response
    assert_equal 'Successful', receipt_in_response.message
  end

  def test_realex_unstore_card
    options = {
      :order_id => generate_unique_id,
      :user => {
        :id => generate_unique_id,
        :first_name => 'John',
        :last_name => 'Smith'
      }
    }
    response = @gateway.store_user(options)
    
    options.merge!(:order_id => generate_unique_id, :payment_method => generate_unique_id)
    store_card_response = @gateway.store(@visa, options)
    
    unstore_card_response = @gateway.unstore(@visa, options)

    assert_not_nil unstore_card_response
    assert_success unstore_card_response
    assert_equal 'Successful', unstore_card_response.message
  end

end
