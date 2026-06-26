# frozen_string_literal: true

class SmsRu
  # Parses the inbound webhook payload SMS.ru POSTs to your callback URL and
  # verifies its signature. SMS.ru sends the records as POST fields
  # `data[0]..data[N]` (so `params["data"]` is a Hash in Rack/Rails, an Array
  # in PHP) plus a `hash` field; acknowledge the webhook by replying with "100".
  #
  #   return head(:forbidden) unless SmsRu::Webhook.valid?(params["data"], params["hash"], api_id)
  #   SmsRu::Webhook.parse(params["data"]).each do |e|
  #     update_delivery(e.id, e.status_code) if e.sms_status?
  #   end
  module Webhook
    # A single decoded webhook record. `raw` keeps every line for record types
    # this gem does not model explicitly.
    #
    # @!attribute [r] type
    #   @return [String] the record type ("sms_status", "callcheck_status", "test")
    # @!attribute [r] id
    #   @return [String, nil] the message id (sms_status) or check id
    #     (callcheck_status); nil for events without one (e.g. "test")
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

      # @return [Boolean] true for SMS.ru's periodic heartbeat record
      def test? = type == "test"
    end

    # @param data [Hash, Array<String>, String, nil] the POST "data" parameter
    # @return [Array<SmsRu::Webhook::Event>] one event per record
    def self.parse(data)
      entries(data).map do |entry|
        lines = entry.to_s.split("\n")
        case lines[0]
        when "sms_status", "callcheck_status" # type / id / status / timestamp
          Event.new(type: lines[0], id: lines[1], status_code: int(lines[2]), created_at: time(lines[3]), raw: lines)
        when "test" # type / timestamp
          Event.new(type: lines[0], id: nil, status_code: nil, created_at: time(lines[1]), raw: lines)
        else # unknown shape — expose only the type and the raw lines
          Event.new(type: lines[0], id: nil, status_code: nil, created_at: nil, raw: lines)
        end
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
    # numbers the fields data[0..N]; Rack delivers them as a Hash, so sort by
    # the numeric key to preserve SMS.ru's order (the signature depends on it).
    #
    # @api private
    # @param data [Hash, Array<String>, String, nil] the POST "data" parameter
    # @return [Array<String>] the records in the order SMS.ru sent them
    def self.entries(data)
      data.is_a?(Hash) ? data.sort_by { |k, _| k.to_i }.map(&:last) : Array(data)
    end

    # Parses an Integer from a webhook line, returning nil for blanks or garbage.
    # @api private
    def self.int(str) = str && Integer(str, exception: false)

    # Converts a unix-timestamp line into a Time, or nil when absent.
    # @api private
    def self.time(str)
      unix = int(str)
      unix && Time.at(unix)
    end
  end
end
