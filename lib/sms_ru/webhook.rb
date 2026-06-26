# frozen_string_literal: true

class SmsRu
  # Parses the inbound webhook payload SMS.ru POSTs to your callback URL and
  # verifies its signature. SMS.ru sends the records as POST fields
  # `data[0]..data[N]` (so `params["data"]` is a Hash in Rack/Rails, an Array
  # in PHP) plus a `hash` field; acknowledge the webhook by replying with "100".
  #
  # {parse} returns one typed event per record — a {SmsRu::Events::SmsStatus},
  # {SmsRu::Events::CallcheckStatus}, {SmsRu::Events::Test}, or
  # {SmsRu::Events::Unknown} — best handled with a case match:
  #
  #   return head(:forbidden) unless SmsRu::Webhook.valid?(params["data"], params["hash"], api_id)
  #   SmsRu::Webhook.parse(params["data"]).each do |event|
  #     case event
  #     when SmsRu::Events::SmsStatus       then update_delivery(event.id, event.status_code)
  #     when SmsRu::Events::CallcheckStatus then confirm(event.id) if event.confirmed?
  #     end
  #   end
  module Webhook
    # @param data [Hash, Array<String>, String, nil] the POST "data" parameter
    # @return [Array<SmsRu::Events::SmsStatus, SmsRu::Events::CallcheckStatus,
    #   SmsRu::Events::Test, SmsRu::Events::Unknown>] one event per record
    def self.parse(data)
      entries(data).map do |entry|
        lines = entry.to_s.split("\n")
        case lines[0]
        when "sms_status"       then Events::SmsStatus.new(**status_fields(lines))
        when "callcheck_status" then Events::CallcheckStatus.new(**status_fields(lines))
        when "test"             then Events::Test.new(created_at: time(lines[1]), raw: lines)
        else                         Events::Unknown.new(type: lines[0].to_s, raw: lines)
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

      expected = OpenSSL::Digest::SHA256.hexdigest("#{api_id}#{entries(data).join}")
      expected.bytesize == hash.bytesize && OpenSSL.fixed_length_secure_compare(expected, hash)
    end

    # Common fields of the "type / id / status / timestamp" status records.
    # @api private
    def self.status_fields(lines)
      { id: lines[1].to_s, status_code: int(lines[2]), created_at: time(lines[3]), raw: lines }
    end

    # Normalizes the `data` param to an ordered Array of record strings. SMS.ru
    # numbers the fields data[0..N]; Rack delivers them as a Hash, so sort by
    # the numeric key to preserve SMS.ru's order (the signature depends on it).
    #
    # @api private
    # @param data [Hash, Array<String>, String, nil] the POST "data" parameter
    # @return [Array<String>] the records in the order SMS.ru sent them
    def self.entries(data)
      data.is_a?(Hash) ? data.sort_by { |k, _| Coerce.integer(k) }.map(&:last) : Array(data)
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
