# frozen_string_literal: true

class SmsRu
  # Parses the inbound webhook payload SMS.ru POSTs to your callback URL.
  # Pass the `data` request parameter (an Array of newline-joined records, or a
  # single record String) and acknowledge the webhook by replying with "100".
  #
  #   events = SmsRu::Webhook.parse(params["data"])
  #   events.each { |e| update_delivery(e.sms_id, e.status_code) if e.sms_status? }
  module Webhook
    # A single decoded webhook record. `raw` keeps every line for record types
    # this gem does not model explicitly.
    #
    # @!attribute [r] type
    #   @return [String] the record type (e.g. "sms_status")
    # @!attribute [r] sms_id
    #   @return [String] the message id the record refers to
    # @!attribute [r] status_code
    #   @return [Integer, nil] the delivery status code, when present
    # @!attribute [r] raw
    #   @return [Array<String>] every line of the original record
    Event = Data.define(:type, :sms_id, :status_code, :raw) do
      # @return [Boolean] true when this record reports an SMS delivery status
      def sms_status? = type == "sms_status"
    end

    # @param data [Array<String>, String, nil] the POST "data" parameter — an
    #   Array of newline-joined records, or a single record String
    # @return [Array<SmsRu::Webhook::Event>] one event per record
    def self.parse(data)
      Array(data).map do |entry|
        lines = entry.to_s.split("\n")
        Event.new(type: lines[0], sms_id: lines[1], status_code: lines[2]&.to_i, raw: lines)
      end
    end
  end
end
