# frozen_string_literal: true

class SmsRu
  # Manages the account stoplist (numbers that never receive messages and are
  # never charged). Reached via SmsRu#stoplist, e.g. `client.stoplist.add(...)`.
  class Stoplist
    # @api private
    # @param request [Method] the client's bound `request` method
    def initialize(request)
      @request = request
    end

    # Adds a number to the stoplist. `note` is visible only to you.
    #
    # @param phone [String, Integer] the number to stoplist
    # @param note [String, nil] an optional private note
    # @return [Boolean] true on success
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def add(phone, note: nil)
      @request.call("/stoplist/add", stoplist_phone: phone.to_s, stoplist_text: note.to_s)
      true
    end

    # Removes a number from the stoplist.
    #
    # @param phone [String, Integer] the number to remove
    # @return [Boolean] true on success
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def remove(phone)
      @request.call("/stoplist/del", stoplist_phone: phone.to_s)
      true
    end

    # Returns every stoplisted number as an Array of SmsRu::StoplistEntry.
    #
    # @return [Array<SmsRu::StoplistEntry>]
    # @raise [SmsRu::ResponseError] if SMS.ru rejects the request
    def list
      data = @request.call("/stoplist/get")
      (data["stoplist"] || {}).map { |phone, note| StoplistEntry.new(phone: phone, note: note) }
    end
  end
end
