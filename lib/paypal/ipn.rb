module Paypal
  module IPN
    def self.endpoint
      _endpoint_ = URI.parse Paypal.endpoint
      _endpoint_.query = {
        :cmd => '_notify-validate'
      }.to_query
      _endpoint_.to_s
    end

    def self.verify!(raw_post)
      connection = Faraday.new(url: endpoint) do |faraday|
        faraday.request :url_encoded
        faraday.response :raise_error
        faraday.adapter Faraday.default_adapter
      end
      
      response = connection.post do |req|
        req.body = raw_post
      end
      
      case response.body
      when 'VERIFIED'
        true
      else
        raise Exception::APIError.new(response.body)
      end
    rescue Faraday::Error => e
      status = e.response ? e.response[:status] : nil
      body = e.response ? e.response[:body] : nil
      raise Exception::HttpError.new(status, e.message, body)
    end
  end
end