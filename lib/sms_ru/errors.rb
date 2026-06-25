# frozen_string_literal: true

class SmsRu
  # Base class for every error raised by the gem. Rescue this to catch them all.
  class Error < StandardError; end

  # Raised when SMS.ru cannot be reached or returns an unparseable body
  # (network failure, timeout, invalid JSON). Retried up to `retries` times first.
  class ConnectionError < Error; end

  # Raised when SMS.ru replies with a non-OK status. Carries the API's numeric
  # `code` and human-readable `text` (status_text).
  #
  # @!attribute [r] code
  #   @return [Integer] the SMS.ru numeric status code
  # @!attribute [r] text
  #   @return [String] the human-readable status text
  class ResponseError < Error
    attr_reader :code, :text

    # @param code [Integer] the SMS.ru numeric status code
    # @param text [String] the human-readable status text
    def initialize(code:, text:)
      @code = code
      @text = text
      super("[#{code}] #{text}")
    end
  end

  # Invalid api_id / token / unconfirmed account (codes 200, 300, 301, 302).
  class AuthError < ResponseError; end

  # Not enough money on the account (code 201).
  class InsufficientFundsError < ResponseError; end
end
