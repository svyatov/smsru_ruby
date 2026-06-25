# frozen_string_literal: true

class SmsRu
  # Manages callback (webhook) URLs that SMS.ru notifies with delivery statuses.
  # Reached via SmsRu#callbacks, e.g. `client.callbacks.add("https://...")`.
  # Each method returns the full Array of registered URLs after the change.
  class Callbacks
    def initialize(request)
      @request = request
    end

    def add(url) = urls(@request.call("/callback/add", url: url))
    def remove(url) = urls(@request.call("/callback/del", url: url))
    def list = urls(@request.call("/callback/get"))

    private

    def urls(data) = data["callback"] || []
  end
end
