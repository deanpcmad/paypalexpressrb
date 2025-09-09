# PayPal Express Checkout Ruby Gem

Originally by [nov/paypal-express](https://github.com/nov/paypal-express).

[![CI](https://github.com/deanpcmad/paypal-express/actions/workflows/ci.yml/badge.svg)](https://github.com/deanpcmad/paypal-express/actions/workflows/ci.yml)

A Ruby client library for PayPal Express Checkout API that supports Instant Payments.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'paypal-express', github: "deanpcmad/paypal-express"
```

And then execute:

```bash
$ bundle install
```

## Configuration

### 1. Get PayPal API Credentials

First, obtain your API credentials from PayPal:

- **Sandbox**: [PayPal Developer](https://developer.paypal.com/) → Create App
- **Production**: [PayPal](https://www.paypal.com/) → Account Settings → API Access

You'll need:
- API Username
- API Password
- API Signature

### 2. Configure the Gem

```ruby
# For development/testing (Sandbox)
Paypal.sandbox!

# For production
Paypal.sandbox = false
```

## Basic Usage

### Instant Payment (One-time Payment)

Here's a complete example of processing a one-time payment:

```ruby
# 1. Create a PayPal Express request
request = Paypal::Express::Request.new(
  username:  'your_api_username',
  password:  'your_api_password',
  signature: 'your_api_signature'
)

# 2. Create a payment request
payment = Paypal::Payment::Request.new(
  amount:      100.00,                    # $100.00
  currency:    'USD',
  description: 'T-Shirt Purchase'
)

# 3. Setup the Express Checkout session
response = request.setup(
  payment,
  'http://your-site.com/success',         # Return URL
  'http://your-site.com/cancel'           # Cancel URL
)

if response.success?
  # 4. Redirect user to PayPal
  redirect_to response.redirect_uri
else
  # Handle error
  flash[:error] = "PayPal setup failed"
end
```

### Handling the Return from PayPal

After the user approves payment on PayPal, they'll return to your success URL:

```ruby
# In your success action (e.g., PaymentController#success)
def success
  token    = params[:token]
  payer_id = params[:PayerID]

  # Get payment details
  details_response = request.details(token)

  if details_response.success?
    # Complete the payment
    checkout_response = request.checkout!(
      token,
      payer_id,
      payment  # Same payment object from setup
    )

    if checkout_response.success?
      # Payment successful!
      transaction_id = checkout_response.payment_info.first.transaction_id

      # Save transaction_id and process the order
      flash[:success] = "Payment completed successfully!"
    else
      flash[:error] = "Payment failed: #{checkout_response.details.first.long_message}"
    end
  end
end
```

### Complete Working Example

```ruby
class PaymentsController < ApplicationController

  def new
    # Show payment form
  end

  def create
    # Create PayPal request
    @request = create_paypal_request

    # Create payment
    @payment = Paypal::Payment::Request.new(
      amount:      params[:amount].to_f,
      currency:    'USD',
      description: params[:description]
    )

    # Setup Express Checkout
    response = @request.setup(
      @payment,
      success_payments_url,
      cancel_payments_url
    )

    if response.success?
      # Store payment info in session for later use
      session[:payment_amount] = params[:amount]
      session[:payment_description] = params[:description]

      redirect_to response.redirect_uri
    else
      flash[:error] = "Unable to setup PayPal payment"
      render :new
    end
  end

  def success
    token    = params[:token]
    payer_id = params[:PayerID]

    return redirect_to new_payment_path unless token && payer_id

    @request = create_paypal_request

    # Recreate payment from session
    @payment = Paypal::Payment::Request.new(
      amount:      session[:payment_amount].to_f,
      currency:    'USD',
      description: session[:payment_description]
    )

    # Get details and complete payment
    details = @request.details(token)

    if details.success?
      checkout = @request.checkout!(token, payer_id, @payment)

      if checkout.success?
        # Payment successful - save transaction
        @transaction_id = checkout.payment_info.first.transaction_id
        @amount = checkout.payment_info.first.amount.total

        # Clear session
        session.delete(:payment_amount)
        session.delete(:payment_description)

        flash[:success] = "Payment completed! Transaction ID: #{@transaction_id}"
      else
        flash[:error] = "Payment failed"
      end
    else
      flash[:error] = "Unable to get payment details"
    end
  end

  def cancel
    flash[:notice] = "Payment was cancelled"
    redirect_to new_payment_path
  end

  private

  def create_paypal_request
    Paypal::Express::Request.new(
      username:  Rails.application.credentials.paypal[:username],
      password:  Rails.application.credentials.paypal[:password],
      signature: Rails.application.credentials.paypal[:signature]
    )
  end
end
```

## Advanced Features

### Multiple Items

```ruby
# Create items
items = [
  Paypal::Payment::Request::Item.new(
    name:        'T-Shirt',
    description: 'Blue T-Shirt Size M',
    amount:      25.00,
    quantity:    2
  ),
  Paypal::Payment::Request::Item.new(
    name:        'Shipping',
    description: 'Standard Shipping',
    amount:      5.00,
    quantity:    1
  )
]

# Create payment with items
payment = Paypal::Payment::Request.new(
  amount:      55.00,  # Total amount
  currency:    'USD',
  description: 'Online Store Purchase',
  items:       items
)
```

### Checking Payment Status

All response objects now support the `success?` method:

```ruby
response = request.setup(payment, return_url, cancel_url)

if response.success?
  # Setup successful
  puts "Token: #{response.token}"
else
  # Handle error
  puts "Error: #{response.ack}"  # Will be "Failure"
end

# Works for all response types
checkout_response = request.checkout!(token, payer_id, payment)
puts "Payment successful!" if checkout_response.success?

details_response = request.details(token)
puts "Got details!" if details_response.success?
```

### IPN (Instant Payment Notification)

```ruby
# In your IPN controller
def notify
  response = request.env['rack.input'].read

  if Paypal::IPN.verify!(response)
    # IPN is valid, process the notification
    params = Rack::Utils.parse_query(response)

    case params['payment_status']
    when 'Completed'
      # Payment completed
    when 'Refunded'
      # Payment refunded
    # Handle other statuses...
    end
  else
    # Invalid IPN - possible fraud attempt
    head :bad_request
  end
end
```

## Configuration Options

### Sandbox vs Production

```ruby
# Sandbox (for testing)
Paypal.sandbox!

# Production
Paypal.sandbox = false

# Check current mode
puts "Sandbox mode: #{Paypal.sandbox?}"
```

### API Version

```ruby
# Set API version (default is latest)
Paypal.api_version = '204.0'
```

### Logging

```ruby
# Custom logger
Paypal.logger = Rails.logger

# Log level
Paypal.logger.level = Logger::INFO
```

### Setup Options

```ruby
response = request.setup(
  payment,
  return_url,
  cancel_url,
  # Options
  no_shipping:        true,          # Don't require shipping address
  allow_note:         false,         # Don't allow buyer notes
  solution_type:      'Sole',        # Don't require PayPal account
  landing_page:       'Billing',     # Go directly to credit card form
  brand:              'My Store',    # Custom brand name
  locale:             'US',          # Locale for PayPal pages
  pay_on_paypal:      true          # Show "Pay with PayPal" button
)
```

## Error Handling

```ruby
begin
  response = request.setup(payment, return_url, cancel_url)

  unless response.success?
    # API returned an error
    puts "PayPal Error: #{response.details.first.long_message}"
  end

rescue Paypal::Exception::APIError => e
  # API returned error response
  puts "API Error: #{e.message}"
  puts "Error Code: #{e.response.details.first.error_code}"

rescue Paypal::Exception::HttpError => e
  # HTTP error (network, etc.)
  puts "HTTP Error: #{e.message} (#{e.code})"

rescue => e
  # Other errors
  puts "Unexpected error: #{e.message}"
end
```

## Testing

For testing, you can use the sandbox mode and PayPal's test accounts:

```ruby
# In test environment
Paypal.sandbox!

# Use PayPal's test credentials
request = Paypal::Express::Request.new(
  username:  'test_api_username',
  password:  'test_api_password',
  signature: 'test_api_signature'
)
```

PayPal provides test credit card numbers and buyer accounts in their developer documentation.

## Ruby Version Support

- Ruby 3.1+
- Ruby 3.2
- Ruby 3.3
- Ruby 3.4

## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Add tests for your changes
4. Make your changes and ensure tests pass (`bundle exec rake spec`)
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create new Pull Request

## Resources

- [PayPal Express Checkout Documentation](https://developer.paypal.com/docs/api/payments/v1/)
- [PayPal Developer Portal](https://developer.paypal.com/)
- [Sample Rails Application](https://github.com/nov/paypal-express-sample)

## License

Copyright (c) 2011 nov matake. See [LICENSE](LICENSE) for details.
