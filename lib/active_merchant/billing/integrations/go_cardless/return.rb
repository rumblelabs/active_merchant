module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module GoCardless
        class Return < ActiveMerchant::Billing::Integrations::Return
          
          attr_reader :params

          def initialize(params)
            @params = case params
            when String
              parse(params)
            when Hash
              params.stringify_keys
            else
              nil
            end
          end

          def id
            params['resource_id']
          end

          def type
            params['resource_type']
          end

          def url
            params['resource_uri']
          end

          def state
            params['state']
          end

          def resource
            method = "#{type}"
            ::GoCardless.client.send(method, id) if ::GoCardless.client.respond_to?(method)
          end

          def confirm!
            ::GoCardless.client.confirm_resource(params)
          end

        end
      end
    end
  end
end
