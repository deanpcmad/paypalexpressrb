require 'spec_helper.rb'

describe Paypal::Payment::Response do
  describe '.new' do
    context 'when non-supported attributes are given' do
      it 'should ignore them and warn' do
        Paypal.logger.should_receive(:warn).with(
          "Ignored Parameter (Paypal::Payment::Response): ignored=Ignore me!"
        )
        response = Paypal::Payment::Response.new(
          :ignored => 'Ignore me!'
        )
      end
    end
  end

  describe '#success?' do
    context 'when ACK is Success' do
      it 'returns true' do
        response = Paypal::Payment::Response.new(:ACK => 'Success')
        response.success?.should be_truthy
      end
    end

    context 'when ACK is Failure' do
      it 'returns false' do
        response = Paypal::Payment::Response.new(:ACK => 'Failure')
        response.success?.should be_falsey
      end
    end

    context 'when ACK is nil' do
      it 'returns false' do
        response = Paypal::Payment::Response.new
        response.success?.should be_falsey
      end
    end
  end
end