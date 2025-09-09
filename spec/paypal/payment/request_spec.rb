require 'spec_helper.rb'

describe Paypal::Payment::Request do
  let :instant_request do
    Paypal::Payment::Request.new(
      :amount => 25.7,
      :tax_amount => 0.4,
      :shipping_amount => 1.5,
      :currency_code => :JPY,
      :description => 'Instant Payment Request',
      :notify_url => 'http://merchant.example.com/notify',
      :invoice_number => 'ABC123',
      :custom => 'Custom',
      :items => [{
        :quantity => 2,
        :name => 'Item1',
        :description => 'Awesome Item 1!',
        :amount => 10.25
      }, {
        :quantity => 3,
        :name => 'Item2',
        :description => 'Awesome Item 2!',
        :amount => 1.1
      }],
      :custom_fields => {
        "l_surveychoice{n}" => 'abcd' # The '{n}' will be replaced with the index
      }
    )
  end


  describe '.new' do
    it 'should handle Instant Payment parameters' do
      instant_request.amount.total.should == 25.7
      instant_request.amount.tax.should == 0.4
      instant_request.amount.shipping.should == 1.5
      instant_request.currency_code.should == :JPY
      instant_request.description.should == 'Instant Payment Request'
      instant_request.notify_url.should == 'http://merchant.example.com/notify'
    end

  end

  describe '#to_params' do
    it 'should handle Instant Payment parameters' do
      instant_request.to_params.should == {
        :PAYMENTREQUEST_0_AMT => "25.70",
        :PAYMENTREQUEST_0_TAXAMT => "0.40",
        :PAYMENTREQUEST_0_SHIPPINGAMT => "1.50",
        :PAYMENTREQUEST_0_CURRENCYCODE => :JPY,
        :PAYMENTREQUEST_0_DESC => "Instant Payment Request",
        :PAYMENTREQUEST_0_NOTIFYURL => "http://merchant.example.com/notify",
        :PAYMENTREQUEST_0_ITEMAMT => "23.80",
        :PAYMENTREQUEST_0_INVNUM => "ABC123",
        :PAYMENTREQUEST_0_CUSTOM => "Custom",
        :L_PAYMENTREQUEST_0_NAME0 => "Item1",
        :L_PAYMENTREQUEST_0_DESC0 => "Awesome Item 1!",
        :L_PAYMENTREQUEST_0_AMT0 => "10.25",
        :L_PAYMENTREQUEST_0_QTY0 => 2,
        :L_PAYMENTREQUEST_0_NAME1 => "Item2",
        :L_PAYMENTREQUEST_0_DESC1 => "Awesome Item 2!",
        :L_PAYMENTREQUEST_0_AMT1 => "1.10",
        :L_PAYMENTREQUEST_0_QTY1 => 3,
        :L_SURVEYCHOICE0 => 'abcd' # Note the 'n' was replaced by the index
      }
    end

  end

  describe '#items_amount' do
    context 'when BigDecimal'
    let(:instance) do
      Paypal::Payment::Request.new(
        :items => [{
          :quantity => 3,
          :name => 'Item1',
          :description => 'Awesome Item 1!',
          :amount => 130.45
        }]
      )
    end

    # NOTE:
    # 130.45 * 3 => 391.34999999999997 (in ruby 1.9)
    it 'should calculate total amount correctly' do
      instance.items_amount.should == 391.35
    end
  end
end
