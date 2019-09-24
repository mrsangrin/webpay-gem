# frozen_string_literal: true

require 'signer'
require 'savon'
require 'util'
require 'error'
require_relative 'verifier'

# WebpayNormal
class WebpayNormal
  TR_NORMAL_WS = 'TR_NORMAL_WS'

  SAVON_DEFAULT_OPTS = {
    log_level: :debug,
    open_timeout: 10,
    read_timeout: 10,
    log: true
  }.freeze

  def initialize(configuration, savon_client_opts = SAVON_DEFAULT_OPTS)
    @wsdl_path = ''
    @environment = configuration.environment

    case @environment
    when 'INTEGRACION'
      @wsdl_path = 'https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSWebpayService?wsdl'
    when 'CERTIFICACION'
      @wsdl_path = 'https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSWebpayService?wsdl'
    when 'PRODUCCION'
      @wsdl_path = 'https://webpay3g.transbank.cl/WSWebpayTransaction/cxf/WSWebpayService?wsdl'
    else
      # Por defecto esta el ambiente de INTEGRACION
      @wsdl_path = 'https://webpay3gint.transbank.cl/WSWebpayTransaction/cxf/WSWebpayService?wsdl'
    end

    @commerce_code = configuration.commerce_code
    @private_key = OpenSSL::PKey::RSA.new(configuration.private_key)
    @public_cert = OpenSSL::X509::Certificate.new(configuration.public_cert)
    @webpay_cert = OpenSSL::X509::Certificate.new(configuration.webpay_cert)

    savon_options = { wsdl: @wsdl_path }
    savon_options.merge!(savon_client_opts)
    @client = Savon.client(savon_options)
  end

  def init_transaction(amount, buy_order, _session_id, return_url, final_url)
    transaction_params = {
      'wsInitTransactionInput' => {
        'wSTransactionType' => TR_NORMAL_WS,
        'buyOrder' => buy_order,
        'sessionId' => sessionId,
        'returnURL' => return_url,
        'finalURL' => final_url,
        'transactionDetails' => {
          'amount' => amount,
          'commerceCode' => @commerce_code,
          'buyOrder' => buy_order
        }
      }
    }

    req = @client.build_request(:init_transaction, message: transaction_params)

    # Firmar documento
    document = Util.xml_sign!(req)
    puts "Documento firmado para #{buy_order} en InitTransaction: #{document.to_s.gsub("\n", '')}"

    begin
      response = @client.call(:init_transaction) do
        xml document.to_xml(save_with: 0)
      end
    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay para #{buyOrder} en InitTransaction: #{e.message}"
      response_array = {
        'error_desc' => "Ocurrio un error en la llamada a Webpay para #{buyOrder} en InitTransaction: #{e.message}"
      }
      return response_array
    end

    # Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      puts "El Certificado de respuesta es Invalido para #{buyOrder} en InitTransaction"
      response_array = {
        'error_desc' => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido para #{buyOrder} en InitTransaction"
    end

    token = ''
    response_document = Nokogiri::HTML(response.to_s)
    response_document.xpath('//token').each do |token_value|
      token = token_value.text
    end
    url = ''
    response_document.xpath('//url').each do |url_value|
      url = url_value.text
    end

    puts "token para #{buyOrder} es #{token}"
    puts "url para #{buyOrder} es #{url}"

    response_array = {
      'token' => token.to_s,
      'url' => url.to_s,
      'error_desc' => 'TRX_OK'
    }

    response_array
  end

  def get_transaction_result(token)
    getResultInput = {
      'tokenInput' => token
    }

    # Preparacion firma
    req = @client.build_request(:get_transaction_result, message: getResultInput)
    # firmar la peticion
    document = sign_xml(req)

    # Se realiza el getResult
    begin
      puts "Iniciando GetResult para #{token}"
      response = @client.call(:get_transaction_result) do
        xml document.to_xml(save_with: 0)
      end
    rescue StandardError => e
      puts "Ocurrio un error en la llamada a Webpay para #{token} en GetResult: #{e.message}"
      response_array = {
        'error_desc' => "Ocurrio un error en la llamada a Webpay para #{token} en GetResult: #{e.message}"
      }
      return response_array
    end

    # Se revisa que respuesta no sea nula.
    if response
      puts "Respuesta GetResult para #{token}: #{response}"
    else
      puts "Webservice Webpay responde con null para #{token}"
      response_array = {
        'error_desc' => 'Webservice Webpay responde con null'
      }
      return response_array
    end

    # Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      puts "El Certificado de respuesta es Invalido para #{token} en GetResult"
      response_array = {
        'error_desc' => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido para #{token} en GetResult"
    end

    response_document = Nokogiri::HTML(response.to_s)

    {
      'accounting_date' => response_document.xpath('//accountingdate').text.to_s,
      'buy_order' => response_document.at_xpath('//buyorder').text.to_s,
      'card_number' => response_document.xpath('//cardnumber').text.to_s,
      'amount' => response_document.xpath('//amount').text.to_s,
      'commerce_code' => response_document.xpath('//commercecode').text.to_s,
      'authorization_code' => response_document.xpath('//authorizationcode').text.to_s,
      'payment_type_code' => response_document.xpath('//paymenttypecode').text.to_s,
      'response_code' => response_document.xpath('//responsecode').text.to_s,
      'transaction_date' => response_document.xpath('//transactiondate').text.to_s,
      'url_redirection' => response_document.xpath('//urlredirection').text.to_s,
      'vci' => response_document.xpath('//vci').text.to_s,
      'shares_number' => response_document.xpath('//sharesnumber').text.to_s,
      'error_desc' => 'TRX_OK'
    }
  end

  def transaction_ack(token)
    request_ack = { 'tokenInput' => token }
    request_ack = @client.build_request(:acknowledge_transaction, message: request_ack)
    signed_xml = Util.xml_sign!(request_ack)

    puts "Iniciando acknowledge_transaction para #{token} ..."
    response_ack = @client.call(:acknowledge_transaction, message: request_ack) do
      xml signed_xml.to_xml(save_with: 0)
    end

    raise(NullAckResponseError, token) if response_ack.blank?

    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    raise(Error::InvalidAckCertResponseError, token) unless Verifier.verify(response_ack, tbk_cert)

    puts "El Certificado de respuesta es Valido para #{token} en acknowledge_transaction"

    { 'error_desc' => 'TRX_OK' }
  rescue StandardError,
         Error::NullAckResponseError,
         Error::InvalidAckCertResponseError => e
    Error.format_ack_error!(e)
  end
end
