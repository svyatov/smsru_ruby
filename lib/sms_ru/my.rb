# frozen_string_literal: true

class SmsRu
  # Account information: balance, daily limit, free quota, and approved sender
  # names. Reached via SmsRu#my, e.g. `client.my.balance`.
  class My
    # @api private
    # @param request [Method] the client's bound `request` method
    def initialize(request)
      @request = request
    end

    # @return [Float] the current account balance, in rubles
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def balance = @request.call("/my/balance")["balance"]

    # @return [SmsRu::Limit] the daily sending limit and today's usage
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def limit = Limit.build(@request.call("/my/limit"))

    # @return [SmsRu::FreeLimit] the free-message allowance and today's usage
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def free_limit = FreeLimit.build(@request.call("/my/free"))

    # @return [Array<String>] the approved sender names on the account
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def senders = @request.call("/my/senders")["senders"] || []
  end
end
