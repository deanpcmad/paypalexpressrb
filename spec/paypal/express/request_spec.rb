require 'spec_helper.rb'

describe Paypal::Express::Request do
  class Paypal::Express::Request
    attr_accessor :_sent_params_, :_method_
    def post_with_logging(method, params)
      self._method_ = method
      self._sent_params_ = params
      post_without_logging method, params
    end
    alias_method :post_without_logging, :post
    alias_method :post, :post_with_logging
  end

  let(:return_url) { 'http://example.com/success' }
  let(:cancel_url) { 'http://example.com/cancel' }
  let(:nvp_endpoint) { Paypal::NVP::Request::ENDPOINT[:production] }
  let :attributes do
    {
      :username => 'nov',
      :password => 'password',
      :signature => 'sig'
    }
  end

  let :instance do
    Paypal::Express::Request.new attributes
  end

  let :instant_payment_request do
    Paypal::Payment::Request.new(
      :amount => 1000,
      :description => 'Instant Payment Request'
    )
  end

  let :many_items do
    items = Array.new
    (1..20).each do |index|
      items << Paypal::Payment::Request::Item.new(
        :name => "Item#{index.to_s}",
        :description => "A new Item #{index.to_s}",
        :amount => 50.00,
        :quantity => 1
      )
    end
  end

  let :instant_payment_request_with_many_items do
       Paypal::Payment::Request.new(
      :amount => 1000,
      :description => 'Instant Payment Request',
      :items => many_items
    )
  end


  describe '.new' do
    context 'when any required parameters are missing' do
      it 'should raise AttrRequired::AttrMissing' do
        attributes.keys.each do |missing_key|
          insufficient_attributes = attributes.reject do |key, value|
            key == missing_key
          end
          expect do
            Paypal::Express::Request.new insufficient_attributes
          end.to raise_error AttrRequired::AttrMissing
        end
      end
    end

    context 'when all required parameters are given' do
      it 'should succeed' do
        expect do
          Paypal::Express::Request.new attributes
        end.not_to raise_error AttrRequired::AttrMissing
      end
    end
  end

  describe '#setup' do
    it 'should return Paypal::Express::Response' do
      fake_response 'SetExpressCheckout/success'
      response = instance.setup instant_payment_request, return_url, cancel_url
      response.should be_instance_of Paypal::Express::Response
    end

    it 'should support no_shipping option' do
      expect do
        instance.setup instant_payment_request, return_url, cancel_url, :no_shipping => true
      end.to request_to nvp_endpoint, :post
      instance._method_.should == :SetExpressCheckout
      instance._sent_params_.should include({
        :PAYMENTREQUEST_0_DESC => 'Instant Payment Request',
        :RETURNURL => return_url,
        :CANCELURL => cancel_url,
        :PAYMENTREQUEST_0_AMT => '1000.00',
        :PAYMENTREQUEST_0_TAXAMT => "0.00",
        :PAYMENTREQUEST_0_SHIPPINGAMT => "0.00",
        :REQCONFIRMSHIPPING => 0,
        :NOSHIPPING => 1
      })
    end

    it 'should support allow_note=false option' do
      expect do
        instance.setup instant_payment_request, return_url, cancel_url, :allow_note => false
      end.to request_to nvp_endpoint, :post
      instance._method_.should == :SetExpressCheckout
      instance._sent_params_.should include({
        :PAYMENTREQUEST_0_DESC => 'Instant Payment Request',
        :RETURNURL => return_url,
        :CANCELURL => cancel_url,
        :PAYMENTREQUEST_0_AMT => '1000.00',
        :PAYMENTREQUEST_0_TAXAMT => "0.00",
        :PAYMENTREQUEST_0_SHIPPINGAMT => "0.00",
        :ALLOWNOTE => 0
      })
    end

    {
      :solution_type => :SOLUTIONTYPE,
      :landing_page => :LANDINGPAGE,
      :email => :EMAIL,
      :brand => :BRANDNAME,
      :locale => :LOCALECODE,
      :logo => :LOGOIMG,
      :cart_border_color => :CARTBORDERCOLOR,
      :payflow_color => :PAYFLOWCOLOR
    }.each do |option_key, param_key|
      it "should support #{option_key} option" do
        expect do
          instance.setup instant_payment_request, return_url, cancel_url, option_key => 'some value'
        end.to request_to nvp_endpoint, :post
        instance._method_.should == :SetExpressCheckout
        instance._sent_params_.should include param_key
        instance._sent_params_[param_key].should == 'some value'
      end
    end

    context 'when instance payment request given' do
      it 'should call SetExpressCheckout' do
        expect do
          instance.setup instant_payment_request, return_url, cancel_url
        end.to request_to nvp_endpoint, :post
        instance._method_.should == :SetExpressCheckout
        instance._sent_params_.should include({
          :PAYMENTREQUEST_0_DESC => 'Instant Payment Request',
          :RETURNURL => return_url,
          :CANCELURL => cancel_url,
          :PAYMENTREQUEST_0_AMT => '1000.00',
          :PAYMENTREQUEST_0_TAXAMT => "0.00",
          :PAYMENTREQUEST_0_SHIPPINGAMT => "0.00"
        })
      end
    end

  end

  describe '#details' do
    it 'should return Paypal::Express::Response' do
      fake_response 'GetExpressCheckoutDetails/success'
      response = instance.details 'token'
      response.should be_instance_of Paypal::Express::Response
    end

    it 'should call GetExpressCheckoutDetails' do
      expect do
        instance.details 'token'
      end.to request_to nvp_endpoint, :post
      instance._method_.should == :GetExpressCheckoutDetails
      instance._sent_params_.should include({
        :TOKEN => 'token'
      })
    end
  end

  describe '#transaction_details' do
    it 'should return Paypal::Express::Response' do
      fake_response 'GetTransactionDetails/success'
      response = instance.transaction_details 'transaction_id'
      response.should be_instance_of Paypal::Express::Response
    end

    it 'should call GetTransactionDetails' do
      expect do
        instance.transaction_details 'transaction_id'
      end.to request_to nvp_endpoint, :post
      instance._method_.should == :GetTransactionDetails
      instance._sent_params_.should include({
        :TRANSACTIONID=> 'transaction_id'
      })
    end

    it 'should fail with bad transaction id' do
      expect do
        fake_response 'GetTransactionDetails/failure'
        response = instance.transaction_details 'bad_transaction_id'
      end.to raise_error(Paypal::Exception::APIError)
    end

    it 'should handle all attributes' do
      Paypal.logger.should_not_receive(:warn)
      fake_response 'GetTransactionDetails/success'
      response = instance.transaction_details 'transaction_id'
    end
  end

  describe "#capture!" do
    it 'should return Paypal::Express::Response' do
      fake_response 'DoCapture/success'
      response = instance.capture! 'authorization_id', 181.98, :BRL
      response.should be_instance_of Paypal::Express::Response
    end

    it 'should call DoExpressCheckoutPayment' do
      expect do
        instance.capture! 'authorization_id', 181.98, :BRL
      end.to request_to nvp_endpoint, :post

      instance._method_.should == :DoCapture
      instance._sent_params_.should include({
        :AUTHORIZATIONID => 'authorization_id',
        :COMPLETETYPE => 'Complete',
        :AMT => 181.98,
        :CURRENCYCODE => :BRL
      })
    end

    it 'should call DoExpressCheckoutPayment with NotComplete capture parameter' do
      expect do
        instance.capture! 'authorization_id', 181.98, :BRL, 'NotComplete'
      end.to request_to nvp_endpoint, :post

      instance._method_.should == :DoCapture
      instance._sent_params_.should include({
        :AUTHORIZATIONID => 'authorization_id',
        :COMPLETETYPE => 'NotComplete',
        :AMT => 181.98,
        :CURRENCYCODE => :BRL
      })
    end
  end

  describe "#void!" do
    it 'should return Paypal::Express::Response' do
      fake_response 'DoVoid/success'
      response = instance.void! 'authorization_id', note: "note"
      response.should be_instance_of Paypal::Express::Response
    end

    it 'should call DoVoid' do
      expect do
        instance.void! 'authorization_id', note: "note"
      end.to request_to nvp_endpoint, :post

      instance._method_.should == :DoVoid
      instance._sent_params_.should include({
        :AUTHORIZATIONID => 'authorization_id',
        :NOTE => "note"
      })
    end
  end

  describe '#checkout!' do
    it 'should return Paypal::Express::Response' do
      fake_response 'DoExpressCheckoutPayment/success'
      response = instance.checkout! 'token', 'payer_id', instant_payment_request
      response.should be_instance_of Paypal::Express::Response
    end

    it 'should call DoExpressCheckoutPayment' do
      expect do
        instance.checkout! 'token', 'payer_id', instant_payment_request
      end.to request_to nvp_endpoint, :post
      instance._method_.should == :DoExpressCheckoutPayment
      instance._sent_params_.should include({
        :PAYERID => 'payer_id',
        :TOKEN => 'token',
        :PAYMENTREQUEST_0_DESC => 'Instant Payment Request',
        :PAYMENTREQUEST_0_AMT => '1000.00',
        :PAYMENTREQUEST_0_TAXAMT => "0.00",
        :PAYMENTREQUEST_0_SHIPPINGAMT => "0.00"
      })
    end

    context "with many items" do
      before do
        fake_response 'DoExpressCheckoutPayment/success_with_many_items'
      end

      it 'should handle all attributes' do
        Paypal.logger.should_not_receive(:warn)
        response = instance.checkout! 'token', 'payer_id', instant_payment_request_with_many_items
      end

      it 'should return Paypal::Express::Response' do
        response = instance.checkout! 'token', 'payer_id', instant_payment_request_with_many_items
        response.should be_instance_of Paypal::Express::Response
      end

      it 'should return twenty items' do
        response = instance.checkout! 'token', 'payer_id', instant_payment_request_with_many_items
        instance._method_.should == :DoExpressCheckoutPayment
        response.items.count.should == 20
      end
    end
  end

  describe '#refund!' do
    it 'should return Paypal::Express::Response' do
      fake_response 'RefundTransaction/full'
      response = instance.refund! 'transaction_id'
      response.should be_instance_of Paypal::Express::Response
    end

    it 'should call RefundTransaction' do
      expect do
        instance.refund! 'transaction_id'
      end.to request_to nvp_endpoint, :post
      instance._method_.should == :RefundTransaction
      instance._sent_params_.should include({
        :TRANSACTIONID => 'transaction_id',
        :REFUNDTYPE => :Full
      })
    end
  end
end
