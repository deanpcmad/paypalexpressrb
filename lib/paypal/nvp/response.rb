module Paypal
  module NVP
    class Response < Base
      cattr_reader :attribute_mapping
      @@attribute_mapping = {
        :ACK => :ack,
        :BUILD => :build,
        :BILLINGAGREEMENTACCEPTEDSTATUS => :billing_agreement_accepted_status,
        :CHECKOUTSTATUS => :checkout_status,
        :CORRELATIONID => :correlation_id,
        :COUNTRYCODE => :country_code,
        :CURRENCYCODE => :currency_code,
        :DESC => :description,
        :NOTIFYURL => :notify_url,
        :TIMESTAMP => :timestamp,
        :TOKEN => :token,
        :VERSION => :version,
        # Some of the attributes below are duplicates of what
        # exists in the payment response, but paypal doesn't
        # prefix these with PAYMENTREQUEST when issuing a
        # GetTransactionDetails response.
        :RECEIVEREMAIL => :receiver_email,
        :RECEIVERID => :receiver_id,
        :SUBJECT => :subject,
        :TRANSACTIONID => :transaction_id,
        :TRANSACTIONTYPE => :transaction_type,
        :PAYMENTTYPE => :payment_type,
        :ORDERTIME => :order_time,
        :PAYMENTSTATUS => :payment_status,
        :PENDINGREASON => :pending_reason,
        :REASONCODE => :reason_code,
        :PROTECTIONELIGIBILITY => :protection_eligibility,
        :PROTECTIONELIGIBILITYTYPE => :protection_eligibility_type,
        :ADDRESSOWNER => :address_owner,
        :ADDRESSSTATUS => :address_status,
        :INVNUM => :invoice_number,
        :CUSTOM => :custom
      }
      attr_accessor *@@attribute_mapping.values
      attr_accessor :shipping_options_is_default, :success_page_redirect_requested, :insurance_option_selected
      attr_accessor :amount, :description, :ship_to, :bill_to, :payer, :refund
      attr_accessor :payment_responses, :payment_info, :items
      alias_method :colleration_id, :correlation_id # NOTE: I made a typo :p

      def initialize(attributes = {})
        attrs = attributes.dup
        @@attribute_mapping.each do |key, value|
          self.send "#{value}=", attrs.delete(key)
        end
        @shipping_options_is_default = attrs.delete(:SHIPPINGOPTIONISDEFAULT) == 'true'
        @success_page_redirect_requested = attrs.delete(:SUCCESSPAGEREDIRECTREQUESTED) == 'true'
        @insurance_option_selected = attrs.delete(:INSURANCEOPTIONSELECTED) == 'true'
        @amount = Payment::Common::Amount.new(
          :total => attrs.delete(:AMT),
          :item => attrs.delete(:ITEMAMT),
          :handing => attrs.delete(:HANDLINGAMT),
          :insurance => attrs.delete(:INSURANCEAMT),
          :ship_disc => attrs.delete(:SHIPDISCAMT),
          :shipping => attrs.delete(:SHIPPINGAMT),
          :tax => attrs.delete(:TAXAMT),
          :fee => attrs.delete(:FEEAMT)
        )
        @ship_to = Payment::Response::Address.new(
          :owner => attrs.delete(:SHIPADDRESSOWNER),
          :status => attrs.delete(:SHIPADDRESSSTATUS),
          :name => attrs.delete(:SHIPTONAME),
          :zip => attrs.delete(:SHIPTOZIP),
          :street => attrs.delete(:SHIPTOSTREET),
          :street2 => attrs.delete(:SHIPTOSTREET2),
          :city => attrs.delete(:SHIPTOCITY),
          :state => attrs.delete(:SHIPTOSTATE),
          :country_code => attrs.delete(:SHIPTOCOUNTRYCODE),
          :country_name => attrs.delete(:SHIPTOCOUNTRYNAME)
        )
        @bill_to = Payment::Response::Address.new(
          :owner => attrs.delete(:ADDRESSID),
          :status => attrs.delete(:ADDRESSSTATUS),
          :name => attrs.delete(:BILLINGNAME),
          :zip => attrs.delete(:ZIP),
          :street => attrs.delete(:STREET),
          :street2 => attrs.delete(:STREET2),
          :city => attrs.delete(:CITY),
          :state => attrs.delete(:STATE),
          :country_code => attrs.delete(:COUNTRY)
        )
        if attrs[:PAYERID]
          @payer = Payment::Response::Payer.new(
            :identifier => attrs.delete(:PAYERID),
            :status => attrs.delete(:PAYERSTATUS),
            :first_name => attrs.delete(:FIRSTNAME),
            :last_name => attrs.delete(:LASTNAME),
            :email => attrs.delete(:EMAIL),
            :company => attrs.delete(:BUSINESS),
            :phone_number => attrs.delete(:PHONENUM)
          )
        end
        if attrs[:REFUNDTRANSACTIONID]
          @refund = Payment::Response::Refund.new(
            :transaction_id => attrs.delete(:REFUNDTRANSACTIONID),
            :amount => {
              :total => attrs.delete(:TOTALREFUNDEDAMOUNT),
              :fee => attrs.delete(:FEEREFUNDAMT),
              :gross => attrs.delete(:GROSSREFUNDAMT),
              :net => attrs.delete(:NETREFUNDAMT)
            }
          )
        end

        # payment_responses
        payment_responses = []
        attrs.keys.each do |_attr_|
          prefix, index, key = case _attr_.to_s
          when /^PAYMENTREQUEST/, /^PAYMENTREQUESTINFO/
            _attr_.to_s.split('_')
          when /^L_PAYMENTREQUEST/
            _attr_.to_s.split('_')[1..-1]
          end
          if prefix
            payment_responses[index.to_i] ||= {}
            payment_responses[index.to_i][key.to_sym] = attrs.delete(_attr_)
          end
        end
        @payment_responses = payment_responses.collect do |_attrs_|
          Payment::Response.new _attrs_
        end

        # payment_info
        payment_info = []
        attrs.keys.each do |_attr_|
          prefix, index, key = _attr_.to_s.split('_')
          if prefix == 'PAYMENTINFO'
            payment_info[index.to_i] ||= {}
            payment_info[index.to_i][key.to_sym] = attrs.delete(_attr_)
          end
        end
        @payment_info = payment_info.collect do |_attrs_|
          Payment::Response::Info.new _attrs_
        end

        # payment_info
        items = []
        attrs.keys.each do |_attr_|
          key, index = _attr_.to_s.scan(/^L_(.+?)(\d+)$/).flatten
          if index
            items[index.to_i] ||= {}
            items[index.to_i][key.to_sym] = attrs.delete(_attr_)
          end
        end
        @items = items.collect do |_attrs_|
          Payment::Response::Item.new _attrs_
        end

        # remove duplicated parameters
        attrs.delete(:SHIPTOCOUNTRY) # NOTE: Same with SHIPTOCOUNTRYCODE
        attrs.delete(:SALESTAX) # Same as TAXAMT

        # warn ignored attrs
        attrs.each do |key, value|
          Paypal.log "Ignored Parameter (#{self.class}): #{key}=#{value}", :warn
        end
      end

      def success?
        ack == 'Success'
      end
    end
  end
end
