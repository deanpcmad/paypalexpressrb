require 'spec_helper.rb'

describe Paypal::NVP::Response do
  let(:return_url) { 'http://example.com/success' }
  let(:cancel_url) { 'http://example.com/cancel' }
  let :request do
    Paypal::Express::Request.new(
      :username => 'nov',
      :password => 'password',
      :signature => 'sig'
    )
  end

  let :payment_request do
    Paypal::Payment::Request.new(
      :amount => 1000,
      :description => 'Instant Payment Request'
    )
  end


  describe '.new' do
    context 'when non-supported attributes are given' do
      it 'should ignore them and warn' do
        Paypal.logger.should_receive(:warn).with(
          "Ignored Parameter (Paypal::NVP::Response): ignored=Ignore me!"
        )
        Paypal::NVP::Response.new(
          :ignored => 'Ignore me!'
        )
      end
    end

    context 'when SetExpressCheckout response given' do
      before do
        fake_response 'SetExpressCheckout/success'
      end

      it 'should handle all attributes' do
        Paypal.logger.should_not_receive(:warn)
        response = request.setup payment_request, return_url, cancel_url
        response.token.should == 'EC-5YJ90598G69065317'
      end
    end

    context 'when GetExpressCheckoutDetails response given' do
      before do
        fake_response 'GetExpressCheckoutDetails/success'
      end

      it 'should handle all attributes' do
        Paypal.logger.should_not_receive(:warn)
        response = request.details 'token'
        response.payer.identifier.should == '9RWDTMRKKHQ8S'
        response.payment_responses.size.should == 1
        response.payment_info.size.should == 0
        response.payment_responses.first.should be_instance_of(Paypal::Payment::Response)
      end

      context 'when BILLINGAGREEMENTACCEPTEDSTATUS included' do
        before do
          fake_response 'GetExpressCheckoutDetails/with_billing_accepted_status'
        end

        it 'should handle all attributes' do
          Paypal.logger.should_not_receive(:warn)
          response = request.details 'token'
        end
      end
    end

    context 'when DoExpressCheckoutPayment response given' do
      before do
        fake_response 'DoExpressCheckoutPayment/success'
      end

      it 'should handle all attributes' do
        Paypal.logger.should_not_receive(:warn)
        response = request.checkout! 'token', 'payer_id', payment_request
        response.payment_responses.size.should == 0
        response.payment_info.size.should == 1
        response.payment_info.first.should be_instance_of(Paypal::Payment::Response::Info)
      end

    end

  end

  describe '#success?' do
    context 'when ACK is Success' do
      it 'returns true' do
        response = Paypal::NVP::Response.new(:ACK => 'Success')
        response.success?.should be_truthy
      end
    end

    context 'when ACK is Failure' do
      it 'returns false' do
        response = Paypal::NVP::Response.new(:ACK => 'Failure')
        response.success?.should be_falsey
      end
    end

    context 'when ACK is nil' do
      it 'returns false' do
        response = Paypal::NVP::Response.new
        response.success?.should be_falsey
      end
    end
  end
end