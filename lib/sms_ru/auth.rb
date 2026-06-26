# frozen_string_literal: true

class SmsRu
  # Authentication checks against the account. Reached via SmsRu#auth, e.g.
  # `client.auth.ok?`.
  class Auth
    # @api private
    # @param request [Method] the client's bound `request` method
    def initialize(request)
      @request = request
    end

    # @return [Boolean] true when the configured api_id is valid
    def ok?
      @request.call("/auth/check")
      true
    rescue AuthError
      false
    end
  end
end
