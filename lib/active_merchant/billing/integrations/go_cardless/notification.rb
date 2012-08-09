module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module GoCardless
        # Handles webhook notifications
        class Notification

          attr_reader :payload

          # Parse  a notification from the webhook JSON body
          def initialize(body)
            @payload = ActiveSupport::JSON.decode(body)['payload']
            @payload = HashWithIndifferentAccess.new(@payload)
          rescue
            raise ArgumentError, "Invalid webhook payload"
          end

          # Type of resource the action occurred on
          def type
            payload['resource_type']
          end

          # What has occurred to the resource(s)
          def action
            payload['action']
          end

          # Array of resources affected
          def resources
            payload["#{type}s"] || []
          end

          # Verifies the calculated signature matches that in the payload
          def valid?
            ::GoCardless.client.webhook_valid?(payload)
          end

        end
      end
    end
  end
end