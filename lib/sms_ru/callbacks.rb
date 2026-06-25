# frozen_string_literal: true

class SmsRu
  # Manages callback (webhook) URLs that SMS.ru notifies with delivery statuses.
  # Reached via SmsRu#callbacks, e.g. `client.callbacks.add("https://...")`.
  # Each method returns the full Array of registered URLs after the change.
  class Callbacks
    # @api private
    # @param request [Method] the client's bound `request` method
    def initialize(request)
      @request = request
    end

    # Registers a callback URL.
    #
    # @param url [String] the webhook URL to register
    # @return [Array<String>] all registered URLs after the change
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def add(url) = urls(@request.call("/callback/add", url: url))

    # Removes a callback URL.
    #
    # @param url [String] the webhook URL to remove
    # @return [Array<String>] all registered URLs after the change
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def remove(url) = urls(@request.call("/callback/del", url: url))

    # Lists the registered callback URLs.
    #
    # @return [Array<String>] all registered URLs
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def list = urls(@request.call("/callback/get"))

    private

    def urls(data) = data["callback"] || []
  end
end
