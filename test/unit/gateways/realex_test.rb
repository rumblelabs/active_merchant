require 'test_helper'
require 'digest/sha1'

class RealexTest < Test::Unit::TestCase
  
  class ActiveMerchant::Billing::RealexGateway
    # For the purposes of testing, lets redefine some protected methods as public.
    public :build_purchase_or_authorization_request, :build_credit_request, :build_void_request, 
      :build_capture_request, :stringify_values, :avs_input_code, :build_cancel_card_request,
      :build_new_card_request, :build_new_payee_request, :build_receipt_in_request, :build_refund_request
  end
  
  def setup
    @login = 'your_merchant_id'
    @password = 'your_secret'
    @account = 'your_account'
    @rebate_secret = 'your_rebate_secret'
  
    @gateway = RealexGateway.new(
      :login => @login,
      :password => @password,
      :account => @account
    )

    @gateway_with_account = RealexGateway.new(
      :login => @merchant_id,
      :password => @secret,
      :account => 'bill_web_cengal'
    )
    
    @credit_card = CreditCard.new(
      :number => '4263971921001307',
      :month => 8,
      :year => 2008,
      :first_name => 'Longbob',
      :last_name => 'Longsen',
      :brand => 'visa'
    )
    
    @options = {
      :order_id => '1'
    }
    
    @address = {
      :name => 'Longbob Longsen',
      :address1 => '123 Fake Street',
      :city => 'Belfast',
      :state => 'Antrim',
      :country => 'Northern Ireland',
      :zip => 'BT2 8XX'
    }
    
    @amount = 100
  end
  
  
  def test_in_test
    assert_equal :test, ActiveMerchant::Billing::Base.gateway_mode
  end  
  
  def test_hash
    gateway = RealexGateway.new(
      :login => 'thestore',
      :password => 'mysecret'
    )
    Time.stubs(:now).returns(Time.parse("2001-04-03 12:32:45"))
    gateway.expects(:ssl_post).with(anything, regexp_matches(/9af7064afd307c9f988e8dfc271f9257f1fc02f6/)).returns(successful_purchase_response)
    gateway.purchase(29900, credit_card('5105105105105100'), :order_id => 'ORD453-11')
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end
  
  def test_unsuccessful_purchase
    @gateway.expects(:ssl_post).returns(unsuccessful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert response.test?
  end
  
  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_refund_response)    
    assert_success @gateway.refund(@amount, '1234;1234;1234', :pasref => 'TEST', :order_id => 123)
  end
  
  def test_unsuccessful_refund
    @gateway.expects(:ssl_post).returns(unsuccessful_refund_response)
    assert_failure @gateway.refund(@amount, '1234;1234;1234', :pasref => 'TEST', :order_id => 123)
  end
  
  def test_deprecated_credit
    @gateway.expects(:ssl_post).returns(successful_refund_response)
    assert_deprecation_warning(Gateway::CREDIT_DEPRECATION_MESSAGE, @gateway) do
      assert_success @gateway.credit(@amount, '1234;1234;1234', :pasref => 'TEST', :order_id => 123)
    end
  end
  
  def test_supported_countries
    assert_equal ['IE', 'GB'], RealexGateway.supported_countries
  end
  
  def test_supported_card_types
    assert_equal [ :visa, :master, :american_express, :diners_club, :switch, :solo, :laser ], RealexGateway.supported_cardtypes
  end
  
  def test_avs_result_not_supported
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
  
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_nil response.avs_result['code']
  end
  
  def test_cvv_result
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
  
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal 'M', response.cvv_result['code']
  end
  
  def test_malformed_xml
    @gateway.expects(:ssl_post).returns(malformed_unsuccessful_purchase_response)
    
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_failure response
    assert_equal '[ test system ] This is  not awesome', response.params['message']
    assert response.test?
  end
  
  def test_capture_xml
    @gateway.expects(:new_timestamp).returns('20090824160201')
    
    valid_capture_xml = <<-SRC
<request timestamp="20090824160201" type="settle">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <pasref>4321</pasref>
  <authcode>1234</authcode>
  <sha1hash>4132600f1dc70333b943fc292bd0ca7d8e722f6e</sha1hash>
</request>
SRC
    
    assert_xml_equal valid_capture_xml, @gateway.build_capture_request('1;4321;1234', {})
  end
  
  def test_purchase_xml
    options = {
      :order_id => '1'
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_purchase_request_xml = <<-SRC
<request timestamp="20090824160201" type="auth">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <amount currency="EUR">100</amount>
  <card>
    <number>4263971921001307</number>
    <expdate>0808</expdate>
    <chname>Longbob Longsen</chname>
    <type>VISA</type>
    <issueno></issueno>
    <cvn>
      <number></number>
      <presind></presind>
    </cvn>
  </card>
  <autosettle flag="1"/>
  <sha1hash>3499d7bc8dbacdcfba2286bd74916d026bae630f</sha1hash>
</request>
SRC

    assert_xml_equal valid_purchase_request_xml, @gateway.build_purchase_or_authorization_request(:purchase, @amount, @credit_card, options)
  end
  
  def test_void_xml
    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_void_request_xml = <<-SRC
<request timestamp="20090824160201" type="void">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <pasref>4321</pasref>
  <authcode>1234</authcode>
  <sha1hash>4132600f1dc70333b943fc292bd0ca7d8e722f6e</sha1hash>
</request>
SRC

    assert_xml_equal valid_void_request_xml, @gateway.build_void_request('1;4321;1234', {})
  end
  
  def test_auth_xml
    options = {
      :order_id => '1'
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_auth_request_xml = <<-SRC
<request timestamp="20090824160201" type="auth">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <amount currency=\"EUR\">100</amount>
  <card>
    <number>4263971921001307</number>
    <expdate>0808</expdate>
    <chname>Longbob Longsen</chname>
    <type>VISA</type>
    <issueno></issueno>
    <cvn>
      <number></number>
      <presind></presind>
    </cvn>
  </card>
  <autosettle flag="0"/>
  <sha1hash>3499d7bc8dbacdcfba2286bd74916d026bae630f</sha1hash>
</request>
SRC

    assert_xml_equal valid_auth_request_xml, @gateway.build_purchase_or_authorization_request(:authorization, @amount, @credit_card, options)
  end
  
  def test_refund_xml
    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_refund_request_xml = <<-SRC
<request timestamp="20090824160201" type="rebate">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>123</orderid>
  <pasref>TEST</pasref>
  <authcode>1234</authcode>
  <amount currency="EUR">100</amount>
  <autosettle flag="1"/>
  <sha1hash>0e099be7c9b6b90b601414330a838b0169df4270</sha1hash>
</request>
SRC

    assert_xml_equal valid_refund_request_xml, @gateway.build_refund_request(@amount, '123;TEST;1234', :currency => 'EUR')

  end
  
  def test_refund_with_rebate_secret_xml
    gateway = RealexGateway.new(:login => @login, :password => @password, :account => @account, :rebate_secret => @rebate_secret)
    
    gateway.expects(:new_timestamp).returns('20090824160201')

    valid_refund_request_xml = <<-SRC
<request timestamp="20090824160201" type="rebate">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>123</orderid>
  <pasref>TEST</pasref>
  <authcode>1234</authcode>
  <amount currency="EUR">100</amount>
  <refundhash>f94ff2a7c125a8ad87e5683114ba1e384889240e</refundhash>
  <autosettle flag="1"/>
  <sha1hash>0e099be7c9b6b90b601414330a838b0169df4270</sha1hash>
</request>
SRC

    assert_xml_equal valid_refund_request_xml, gateway.build_refund_request(@amount, '123;TEST;1234', :currency => 'EUR')

  end
  
  def test_should_extract_avs_input
    address = {:address1 => "123 Fake Street", :zip => 'BT1 0HX'}
    assert_equal "10|123", @gateway.avs_input_code(address)
  end

  def test_auth_with_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    options = {
      :order_id => '1',
      :billing_address => @address,
      :shipping_address => @address
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')
    
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
  end

  def test_zip_in_shipping_address
    @gateway.expects(:ssl_post).with(anything, regexp_matches(/<code>BT28XX<\/code>/)).returns(successful_purchase_response)
    
    options = {
      :order_id => '1',
      :billing_address => @address,
      :shipping_address => @address
    }

    @gateway.authorize(@amount, @credit_card, options)
  end

  def test_auth_with_address
    @gateway.expects(:ssl_post).returns(successful_purchase_response)
    
    options = {
      :order_id => '1',
      :billing_address => @address,
      :shipping_address => @address
    }
    
    response = @gateway.authorize(@amount, @credit_card, options)
    assert_instance_of Response, response
    assert_success response
    assert response.test?
    
  end
  
  def test_address_with_avs_code
    options = {
      :billing_address => @address
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')    
    request = @gateway.build_purchase_or_authorization_request(:purchase, @amount, @credit_card, options)
    
    avs_request = <<-SRC
<request timestamp="20090824160201" type="auth">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid></orderid>
  <amount currency="EUR">100</amount>
  <card>
    <number>4263971921001307</number>
    <expdate>0808</expdate>
    <chname>Longbob Longsen</chname>
    <type>VISA</type>
    <issueno></issueno>
    <cvn>
      <number></number>
      <presind></presind>
    </cvn>
  </card>
  <autosettle flag="1"/>
  <sha1hash>2cf9b05d95c7a2eefc3936989b2696a189b518c9</sha1hash>
  <tssinfo>
    <address type="billing">
      <code>28|123</code>
      <country>Northern Ireland</country>
    </address>
  </tssinfo>
</request>
SRC

    assert_equal avs_request, request
  end

  def test_skip_avs_check
    options = {
      :billing_address => @address,
      :skip_avs_check => true
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')    
    request = @gateway.build_purchase_or_authorization_request(:purchase, @amount, @credit_card, options)
    
    avs_request = <<-SRC
<request timestamp="20090824160201" type="auth">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid></orderid>
  <amount currency="EUR">100</amount>
  <card>
    <number>4263971921001307</number>
    <expdate>0808</expdate>
    <chname>Longbob Longsen</chname>
    <type>VISA</type>
    <issueno></issueno>
    <cvn>
      <number></number>
      <presind></presind>
    </cvn>
  </card>
  <autosettle flag="1"/>
  <sha1hash>2cf9b05d95c7a2eefc3936989b2696a189b518c9</sha1hash>
  <tssinfo>
    <address type="billing">
      <code>BT2 8XX</code>
      <country>Northern Ireland</country>
    </address>
  </tssinfo>
</request>
SRC

    assert_equal avs_request, request
  end

  def test_payee_new_xml
    gateway = RealexGateway.new(:login => @login, :password => @password, :account => @account)
    options = {
      :order_id => '1',
      :user => {
        :id => 1,
        :first_name => 'John',
        :last_name => 'Smith'
      }
    }

    gateway.expects(:new_timestamp).returns('20090824160201')

    valid_new_payee_request_xml = <<-SRC
<request timestamp="20090824160201" type="payer-new">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <payer type="Business" ref="1">
    <firstname>John</firstname>
    <surname>Smith</surname>
  </payer>
  <sha1hash>388dd92c8b251ee8970fb4770dc0fed31aa6f1ba</sha1hash>
</request>
SRC
  
    assert_equal valid_new_payee_request_xml, gateway.build_new_payee_request(options)

  end
  
  def test_new_card_xml
    gateway = RealexGateway.new(:login => @login, :password => @password, :account => @account)
    options = {
      :order_id => '1',
      :payment_method => 'visa01',
      :user => {
        :id => 1,
        :first_name => 'John',
        :last_name => 'Smith'
      }
    }

    gateway.expects(:new_timestamp).returns('20090824160201')

    valid_new_card_request_xml = <<-SRC
<request timestamp="20090824160201" type="card-new">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <card>
    <ref>visa01</ref>
    <payerref>1</payerref>
    <number>4263971921001307</number>
    <expdate>0808</expdate>
    <chname>Longbob Longsen</chname>
    <type>VISA</type>
    <issueno></issueno>
    <cvn>
      <number></number>
      <presind></presind>
    </cvn>
  </card>
  <sha1hash>2b95dd150f1d7192fe1e4c2d701f826883e5956b</sha1hash>
</request>
SRC

    assert_equal valid_new_card_request_xml, gateway.build_new_card_request(@credit_card, options)

  end

  def test_receipt_in_xml
    gateway = RealexGateway.new(:login => @login, :password => @password, :account => @account)
    options = {
      :order_id => '1',
      :payment_method => 'visa01',
      :user => {
        :id => 1,
        :first_name => 'John',
        :last_name => 'Smith'
      }
    }

    @gateway.expects(:new_timestamp).returns('20090824160201')

    valid_receipt_in_request_xml = <<-SRC
<request timestamp="20090824160201" type="receipt-in">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <orderid>1</orderid>
  <amount currency=\"EUR\">100</amount>
  <payerref>1</payerref>
  <paymentmethod>visa01</paymentmethod>
  <autosettle flag="1"/>
  <sha1hash>f8365c0ba649e82bed6eebc1043e6a211919676e</sha1hash>
</request>
SRC

    assert_equal valid_receipt_in_request_xml, @gateway.build_receipt_in_request(@amount, @credit_card, options)

  end

  def test_card_unstore_xml
    gateway = RealexGateway.new(:login => @login, :password => @password, :account => @account)
    options = {
      :order_id => '1',
      :payment_method => 'visa01',
      :user => {
        :id => 1,
        :first_name => 'John',
        :last_name => 'Smith'
      }
    }

    gateway.expects(:new_timestamp).returns('20090824160201')

    valid_cancel_card_request_xml = <<-SRC
<request timestamp="20090824160201" type="card-cancel-card">
  <merchantid>your_merchant_id</merchantid>
  <account>your_account</account>
  <card>
    <ref>visa01</ref>
    <payerref>1</payerref>
    <expdate>0808</expdate>
  </card>
  <sha1hash>ff0d7ff2ff82fef20de477b4d91478533bd4ab85</sha1hash>
</request>
SRC

    assert_equal valid_cancel_card_request_xml, gateway.build_cancel_card_request(@credit_card, options)

  end


  private
  
  def successful_purchase_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>00</result>
  <message>[ test system ] message returned from system</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <cardissuer>
    <bank>Issuing Bank Name</bank>
    <country>Issuing Bank Country</country>
    <countrycode>Issuing Bank Country Code</countrycode>
    <region>Issuing Bank Region</region>
  </cardissuer>
  <tss>
    <result>89</result>
    <check id="1000">9</check>
    <check id="1001">9</check>
  </tss>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end
  
  def unsuccessful_purchase_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>01</result>
  <message>[ test system ] message returned from system</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <cardissuer>
    <bank>Issuing Bank Name</bank>
    <country>Issuing Bank Country</country>
    <countrycode>Issuing Bank Country Code</countrycode>
    <region>Issuing Bank Region</region>
  </cardissuer>
  <tss>
    <result>89</result>
    <check id="1000">9</check>
    <check id="1001">9</check>
  </tss>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end
  
  def malformed_unsuccessful_purchase_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>01</result>
  <message>[ test system ] This is & not awesome</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <cardissuer>
    <bank>Issuing Bank Name</bank>
    <country>Issuing Bank Country</country>
    <countrycode>Issuing Bank Country Code</countrycode>
    <region>Issuing Bank Region</region>
  </cardissuer>
  <tss>
    <result>89</result>
    <check id="1000">9</check>
    <check id="1001">9</check>
  </tss>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end
  
  def successful_refund_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>00</result>
  <message>[ test system ] message returned from system</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end

  def unsuccessful_refund_response
    <<-RESPONSE
<response timestamp='20010427043422'>
  <merchantid>your merchant id</merchantid>
  <account>account to use</account>
  <orderid>order id from request</orderid>
  <authcode>authcode received</authcode>
  <result>508</result>
  <message>[ test system ] You may only rebate up to 115% of the original amount.</message>
  <pasref> realex payments reference</pasref>
  <cvnresult>M</cvnresult>
  <batchid>batch id for this transaction (if any)</batchid>
  <sha1hash>7384ae67....ac7d7d</sha1hash>
  <md5hash>34e7....a77d</md5hash>
</response>"
    RESPONSE
  end

  require 'nokogiri'
  def assert_xml_equal(expected, actual)
    assert_xml_equal_recursive(Nokogiri::XML(expected).root, Nokogiri::XML(actual).root)
  end

  def assert_xml_equal_recursive(a, b)
    assert_equal(a.name, b.name)
    assert_equal(a.text, b.text)
    a.attributes.zip(b.attributes).each do |(_, a1), (_, b1)|
      assert_equal a1.name, b1.name
      assert_equal a1.value, b1.value
    end
    a.children.zip(b.children).all?{|a1, b1| assert_xml_equal_recursive(a1, b1)}
  end

  def successful_payer_new_response
    <<-RESPONSE
    <response timestamp="20080611122312">
    <merchantid>yourmerchantid</merchantid>
    <account>internet</account>
    <orderid>transaction01</orderid>
    <result>00</result>
    <message>Successful</message>
    <pasref>5e6b67d303404710a98a4f18abdcd402</pasref>
    <authcode></authcode>
    <batchid></batchid>
    <timetaken>0</timetaken>
    <processingtimetaken></processingtimetaken>
    <md5hash>ff3be479aca946522a9d72d792855018</md5hash>
    <sha1hash>2858c85a5e380e9dc9398329bbd1f086527fc2a7</sha1hash>
    </response>
  RESPONSE
  end

  def successful_payer_edit_response
    <<-RESPONSE
    <response timestamp="20080619114736">
    <merchantid>yourmerchantid</merchantid>
    <account>internet</account>
    <orderid>transaction01</orderid>
    <result>00</result>
    <message>Successful</message>
    <pasref>889510cbf2e74b27b745b2b9b908fabf</pasref>
    <authcode></authcode>
    <batchid></batchid>
    <timetaken>0</timetaken>
    <processingtimetaken></processingtimetaken>
    <md5hash>0bcbd8187c2e2ff48668bca26c706a39</md5hash>
    <sha1hash>7cd0d46c65d6985b7871a7e682451be5ac1b5a2d</sha1hash>
    </response>
  RESPONSE
  end

  def successful_card_store_response
    <<-RESPONSE
    <response timestamp="20080619120024">
    <merchantid>yourmerchantid</merchantid>
    <account>internet</account>
    <orderid>transaction01</orderid>
    <result>00</result>
    <message>Successful</message>
    <pasref>6326ce64fbe340d699433dfc01785c69</pasref>
    <authcode></authcode>
    <batchid></batchid>
    <timetaken>0</timetaken>
    <processingtimetaken></processingtimetaken>
    <md5hash>e41b9e80d0421930131572d66c830407</md5hash>
    <sha1hash>281e5be5a58c7e26b2a6aa31018177960a9c49ab</sha1hash>
    </response>
  RESPONSE
  end

  def unsuccessful_card_store_response
    <<-RESPONSE
    <response timestamp="20080619120121">
    <merchantid></merchantid>
    <account></account>
    <orderid></orderid>
    <result>501</result>
    <message>This Card Ref [cardref01] has already been used [Perhaps you've already set up this
    card for this Payer?]</message>
    <pasref></pasref>
    <authcode></authcode>
    <batchid></batchid>
    <timetaken>1</timetaken>
    <processingtimetaken></processingtimetaken>
    <md5hash>ce30d3ea0e4c9b3d152b61bc5dc93fba</md5hash>
    <sha1hash>8f00805dc22a8832ad43ba2d31ba1ee868ed51f9</sha1hash>
    </response>
    RESPONSE
  end
  
  def successful_reccurring_response
    <<-RESPONSE
    <response timestamp="20080611121850">
    <merchantid>yourmerchantid</merchantid>
    <account>internet</account>
    <orderid>transaction01</orderid>
    <result>00</result>
    <message>Successful</message>
    <pasref>6210a82bba414793ba391254dffbbf77</pasref>
    <authcode></authcode>
    <batchid>161</batchid>
    <timetaken>1</timetaken>
    <processingtimetaken></processingtimetaken>
    <md5hash>22049e6b2c68a5a3942a615c46a1bd72</md5hash>
    <sha1hash>ddd37a93aa377e8c85b42ff4c3a1f88db33ea977</sha1hash>
    </response>
    RESPONSE
  end
  
  def unsucessful_recurring_response
    <<-RESPONSE
    <response timestamp="20080611122328">
    <merchantid>yourmerchantid</merchantid>
    <account>internet</account>
    <result>520</result>
    <message>There is no such Payment Method [cardref] configured for that Payer
    [payerref]</message>
    </response>
    RESPONSE
  end

end
