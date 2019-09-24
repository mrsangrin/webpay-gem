require 'signer'
require 'savon'
require_relative 'verifier'
require_relative 'configuration'
require_relative 'webpay'
# Libwebpay class
class Libwebpay
  attr_accessor :configuration, :webpay
  def initialize(config)
    @configuration = Configuration.new
    @webpay = Webpay.new(config)
  end
end
