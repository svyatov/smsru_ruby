# frozen_string_literal: true

class SmsRu
  # Authorizes a user by an incoming call from their own number: SMS.ru hands you
  # a number, the user calls it, SMS.ru drops the call (free for the caller) and
  # marks the check confirmed. Reached via SmsRu#callcheck.
  #
  #   check = client.callcheck.add("79991234567")
  #   # show check.call_phone_pretty to the user, then poll until confirmed:
  #   client.callcheck.status(check.check_id).confirmed?
  class CallCheck
    # @api private
    # @param request [Method] the client's bound `request` method
    def initialize(request)
      @request = request
    end

    # Starts a check and returns the number the user must call to authorize.
    #
    # @param phone [String, Integer] the user's phone number to authorize
    # @return [SmsRu::CallCheckResult]
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def add(phone) = CallCheckResult.build(@request.call("/callcheck/add", phone: phone.to_s))

    # Polls whether the user has placed the authorizing call yet.
    #
    # @param check_id [String, Integer] the id returned by #add
    # @return [SmsRu::CallCheckStatus]
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def status(check_id) = CallCheckStatus.build(@request.call("/callcheck/status", check_id: check_id.to_s))
  end
end
