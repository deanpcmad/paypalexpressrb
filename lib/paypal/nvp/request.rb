module Paypal
  module NVP
    class Request < Base
      attr_required :username, :password, :signature
      attr_optional :subject
      attr_accessor :version

      ENDPOINT = {
        :production => 'https://api-3t.paypal.com/nvp',
        :sandbox => 'https://api-3t.sandbox.paypal.com/nvp'
      }

      def self.endpoint
        if Paypal.sandbox?
          ENDPOINT[:sandbox]
        else
          ENDPOINT[:production]
        end
      end

      def initialize(attributes = {})
        @version = Paypal.api_version
        super
        self.subject ||= ''
      end

      def common_params
        {
          :USER => self.username,
          :PWD => self.password,
          :SIGNATURE => self.signature,
          :SUBJECT => self.subject,
          :VERSION => self.version
        }
      end

      def request(method, params = {})
        handle_response do
          post(method, params)
        end
      end

      private

      def post(method, params)
        connection = Faraday.new(url: self.class.endpoint) do |faraday|
          faraday.request :url_encoded
          faraday.response :raise_error
          faraday.adapter Faraday.default_adapter
        end
        
        response = connection.post do |req|
          req.body = common_params.merge(params).merge(:METHOD => method)
        end
        
        response.body
      end

      def handle_response
        response = yield
        response = CGI.parse(response).inject({}) do |res, (k, v)|
          res.merge!(k.to_sym => v.first)
        end
        case response[:ACK]
        when 'Success', 'SuccessWithWarning'
          response
        else
          raise Exception::APIError.new(response)
        end
      rescue Faraday::Error => e
        status = e.response ? e.response[:status] : nil
        body = e.response ? e.response[:body] : nil
        raise Exception::HttpError.new(status, e.message, body)
      end
    end
  end
end