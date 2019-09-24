# frozen_string_literal: true

module Error
  # When Ws Reponse is null
  class NullAckResponseError < StandardError
    ERROR = 'WSWebpay responde con null en acknowledge_transaction con '
    def initialize(message)
      super
      @message = "#{ERROR} #{message}"
    end
  end

  # When Cert Reponse is null
  class InvalidAckCertResponseError < StandardError
    ERROR = 'Certificado Invalido acknowledge_transaction '
    def initialize(message)
      super
      @message = "#{ERROR} #{message}"
    end
  end

  def self.format_ack_error!(error)
    ack_error =
      if error.is_a?(Error::NullAckResponseError)
        { 'error_desc' => 'Webservice Webpay responde con null' }
      elsif error.is_a?(Error::InvalidAckCertResponseError)
        { 'error_desc' => 'El Certificado de respuesta es Invalido' }
      else
        { 'error_desc' => "Error en llamada ACK:  #{error.message}" }
      end
    ack_error
  end
end
