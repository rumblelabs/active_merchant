require 'gocardless'

require File.dirname(__FILE__) + '/go_cardless/notification.rb'
require File.dirname(__FILE__) + '/go_cardless/return.rb'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module GoCardless

        class ClientError < StandardError; end;

        def self.configure(options)
          ::GoCardless.account_details = options
        end

        RESOURCES = [:subscription, :bill, :pre_authorization, :payment]

        (RESOURCES - [:payment]).each do |resource|
          define_singleton_method :"#{resource}_url" do |options|
            ensure_client!
            ::GoCardless.client.send(:"new_#{resource}_url", options)
          end
        end

        RESOURCES.each do |resource|
          define_singleton_method resource do |id|
            ensure_client!
            ::GoCardless.client.send(resource, id)
          end
        end

        def self.ensure_client!
          raise ClientError, "The GoCardless client must be configured before use" unless ::GoCardless.client
        end

        def self.return(params)
          Return.new(params)
        end

        def self.notification(payload)
          Notification.new(payload)
        end

      end
    end
  end
end
