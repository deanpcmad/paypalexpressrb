module Paypal
  module Express
    class Request < NVP::Request

      # Common

      def setup(payment_requests, return_url, cancel_url, options = {})
        params = {
          :RETURNURL => return_url,
          :CANCELURL => cancel_url,
          :version   => Paypal.api_version
        }
        if options[:no_shipping]
          params[:REQCONFIRMSHIPPING] = 0
          params[:NOSHIPPING] = 1
        end

        params[:ALLOWNOTE] = 0 if options[:allow_note] == false

        {
          :solution_type => :SOLUTIONTYPE,
          :landing_page  => :LANDINGPAGE,
          :email         => :EMAIL,
          :brand         => :BRANDNAME,
          :locale        => :LOCALECODE,
          :logo          => :LOGOIMG,
          :cart_border_color => :CARTBORDERCOLOR,
          :payflow_color => :PAYFLOWCOLOR
        }.each do |option_key, param_key|
          params[param_key] = options[option_key] if options[option_key]
        end
        Array(payment_requests).each_with_index do |payment_request, index|
          params.merge! payment_request.to_params(index)
        end
        response = self.request :SetExpressCheckout, params
        Response.new response, options
      end

      def details(token)
        response = self.request :GetExpressCheckoutDetails, {
          :TOKEN => token,
          :version   => Paypal.api_version
        }
        Response.new response
      end

      def transaction_details(transaction_id)
        response = self.request :GetTransactionDetails, {:TRANSACTIONID=> transaction_id}
        Response.new response
      end

      def checkout!(token, payer_id, payment_requests)
        params = {
          :TOKEN => token,
          :PAYERID => payer_id,
          :version   => Paypal.api_version
        }
        Array(payment_requests).each_with_index do |payment_request, index|
          params.merge! payment_request.to_params(index)
        end
        response = self.request :DoExpressCheckoutPayment, params
        Response.new response
      end

      def capture!(authorization_id, amount, currency_code, complete_type = 'Complete')
        params = {
          :AUTHORIZATIONID => authorization_id,
          :COMPLETETYPE => complete_type,
          :AMT => amount,
          :CURRENCYCODE => currency_code
        }

        response = self.request :DoCapture, params
        Response.new response
      end

      def void!(authorization_id, params={})
        params = {
          :AUTHORIZATIONID => authorization_id,
          :NOTE => params[:note]
        }

        response = self.request :DoVoid, params
        Response.new response
      end

      # Refund Specific

      def refund!(transaction_id, options = {})
        params = {
          :TRANSACTIONID => transaction_id,
          :REFUNDTYPE => :Full
        }
        if options[:invoice_id]
          params[:INVOICEID] = options[:invoice_id]
        end
        if options[:type]
          params[:REFUNDTYPE] = options[:type]
          params[:AMT] = options[:amount]
          params[:CURRENCYCODE] = options[:currency_code]
        end
        if options[:note]
          params[:NOTE] = options[:note]
        end
        response = self.request :RefundTransaction, params
        Response.new response
      end

    end
  end
end
