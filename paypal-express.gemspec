Gem::Specification.new do |s|
  s.name = "paypal-express"
  s.version = File.read(File.join(File.dirname(__FILE__), "VERSION"))
  s.authors = ["Dean Perry"]
  s.email = "dean@deanpcmad.com"
  s.description = %q{PayPal Express Checkout API Client for instant payments.}
  s.summary = %q{PayPal Express Checkout API Client for instant payments.}
  s.homepage = "http://github.com/deanpcmad/paypalexpressrb"
  s.require_paths = ["lib"]
  s.files = `git ls-files`.split("\n")
  s.add_dependency "activesupport", ">= 2.3"
  s.add_dependency "faraday", "~> 2.0"
  s.add_dependency "attr_required", ">= 0.0.5"
end
