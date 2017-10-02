require_relative 'webpay_mall_normal'
require_relative 'webpay_normal'
require_relative 'webpay_nullify'
require_relative 'webpay_capture'
require_relative 'webpay_one_click'
require_relative 'webpay_complete'

class Webpay

  @configuration
  @webpay_normal
  @webpay_mall_normal
  @webpay_nullify
  @webpay_capture
  @webpay_one_click
  @webpay_complete_transaction


  # método inicializar clase
  def initialize(params)
    @configuration = params
  end

  def get_normal_transaction
    @webpay_normal = WebpayNormal.new(@configuration) if @webpay_normal.nil?
    @webpay_normal
  end

  def get_mall_normal_transaction
    @webpay_mall_normal = WebpayMallNormal.new(@configuration) if @webpay_mall_normal.nil?
    @webpay_mall_normal
  end

  def get_nullify_transaction
    @webpay_nullify = WebpayNullify.new(@configuration) if @webpay_nullify.nil?
    @webpay_nullify
  end

  def get_capture_transaction
    @webpay_capture = WebpayCapture.new(@configuration) if @webpay_capture.if nil?
    @webpay_capture
  end

  def get_one_click_transaction
    @webpay_one_click = WebpayOneClick.new(@configuration) if @webpay_one_click.nil?
    @webpay_one_click
  end

  def get_complete_transaction
    @webpay_complete_transaction = WebpayComplete.new(@configuration) if @webpay_complete_transaction.nil?
    @webpay_complete_transaction
  end
end



