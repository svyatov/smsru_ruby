# frozen_string_literal: true

class SmsRu
  # Parses the inbound webhook payload SMS.ru POSTs to your callback URL and
  # verifies its signature. SMS.ru sends the records as POST fields
  # `data[1]..data[100]` (so `params["data"]` is a Hash in Rack/Rails, an Array
  # in PHP) plus a `hash` field; acknowledge the webhook by replying with "100".
  #
  #   return head(:forbidden) unless SmsRu::Webhook.valid?(params["data"], params["hash"], api_id)
  #   SmsRu::Webhook.parse(params["data"]).each do |e|
  #     update_delivery(e.id, e.status_code) if e.sms_status?
  #   end
  module Webhook
    # A single decoded webhook record. Both event types share one layout:
    # type, id, status code, and creation time. `raw` keeps every line for
    # record types this gem does not model explicitly.
    #
    # @!attribute [r] type
    #   @return [String] the record type ("sms_status" or "callcheck_status")
    # @!attribute [r] id
    #   @return [String] the message id (sms_status) or check id (callcheck_status)
    # @!attribute [r] status_code
    #   @return [Integer, nil] the status code (per /sms/status or /callcheck/status)
    # @!attribute [r] created_at
    #   @return [Time, nil] when SMS.ru created the status
    # @!attribute [r] raw
    #   @return [Array<String>] every line of the original record
    Event = Data.define(:type, :id, :status_code, :created_at, :raw) do
      # @return [Boolean] true when this record reports an SMS delivery status
      def sms_status? = type == "sms_status"

      # @return [Boolean] true when this record reports a call-authorization status
      def callcheck_status? = type == "callcheck_status"
    end

    # @param data [Hash, Array<String>, String, nil] the POST "data" parameter
    # @return [Array<SmsRu::Webhook::Event>] one event per record
    def self.parse(data)
      entries(data).map do |entry|
        lines = entry.to_s.split("\n")
        ts = lines[3] && Integer(lines[3], exception: false)
        Event.new(
          type: lines[0],
          id: lines[1],
          status_code: lines[2] && Integer(lines[2], exception: false),
          created_at: ts && Time.at(ts),
          raw: lines
        )
      end
    end

    # Verifies the payload genuinely came from SMS.ru (constant-time compare of
    # SMS.ru's `hash` against `sha256(api_id + concatenated data entries)`).
    #
    # @param data [Hash, Array<String>, String, nil] the POST "data" parameter
    # @param hash [String, nil] the POST "hash" parameter
    # @param api_id [String] your SMS.ru API id
    # @return [Boolean] true when the signature matches
    def self.valid?(data, hash, api_id)
      return false unless hash.is_a?(String)

      expected = OpenSSL::Digest.hexdigest("SHA256", "#{api_id}#{entries(data).join}")
      expected.bytesize == hash.bytesize && OpenSSL.fixed_length_secure_compare(expected, hash)
    end

    # Normalizes the `data` param to an ordered Array of record strings. SMS.ru
    # numbers the fields data[1..100]; Rack delivers them as a Hash, so sort by
    # the numeric key to preserve SMS.ru's order (the signature depends on it).
    #
    # @api private
    # @param data [Hash, Array<String>, String, nil] the POST "data" parameter
    # @return [Array<String>] the records in the order SMS.ru sent them
    def self.entries(data)
      data.is_a?(Hash) ? data.sort_by { |k, _| k.to_i }.map(&:last) : Array(data)
    end
  end
end
