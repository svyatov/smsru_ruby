# frozen_string_literal: true

class SmsRu
  # Collection helpers shared by results that wrap a `messages` array of
  # per-recipient entries (each responding to #ok?): SmsRu::SendResult and
  # SmsRu::Cost. There is intentionally no lookup-by-phone, since one request may
  # target the same number more than once.
  module MessageCollection
    # @return [Boolean] true when every recipient succeeded
    def ok? = messages.all?(&:ok?)

    # @return [Array] the recipient entries that succeeded
    def ok = messages.select(&:ok?)

    # @return [Array] the recipient entries that failed
    def failed = messages.reject(&:ok?)
  end

  # A single message inside a send response (one entry of the `sms` object).
  # `error_code`/`error_text` are populated only when this recipient was rejected.
  #
  # @!attribute [r] phone
  #   @return [String] the recipient's phone number
  # @!attribute [r] sms_id
  #   @return [String, nil] the message id assigned by SMS.ru (nil when rejected)
  # @!attribute [r] error_code
  #   @return [Integer, nil] the rejection code, or nil when accepted
  # @!attribute [r] error_text
  #   @return [String, nil] the rejection reason, or nil when accepted
  class Sms < Data.define(:phone, :sms_id, :error_code, :error_text)
    # @param phone [String] the recipient's phone number
    # @param hash [Hash] one entry of the response `sms` object
    # @return [SmsRu::Sms]
    def self.build(phone, hash)
      ok = Coerce.string(hash["status"]) == "OK"
      new(
        phone: String(phone),
        sms_id: Coerce.string?(hash["sms_id"]),
        error_code: ok ? nil : Coerce.integer(hash["status_code"]),
        error_text: ok ? nil : Coerce.string(hash["status_text"])
      )
    end

    # @return [Boolean] true when this recipient was accepted
    def ok? = error_code.nil?
  end

  # Result of SmsRu#deliver. `messages` holds one Sms per recipient; individual
  # recipients may have failed even when the overall request succeeded (use #ok?
  # or #failed to tell).
  #
  # @!attribute [r] balance
  #   @return [Float] the account balance after the request
  # @!attribute [r] messages
  #   @return [Array<SmsRu::Sms>] one entry per recipient
  class SendResult < Data.define(:balance, :messages)
    include MessageCollection

    # @param hash [Hash] the parsed /sms/send response
    # @return [SmsRu::SendResult]
    def self.build(hash)
      messages = Coerce.records(hash["sms"]).map { |phone, sms| Sms.build(phone, sms) }
      new(balance: Coerce.float(hash["balance"]), messages: messages)
    end
  end

  # Delivery status of one message (one entry of a /sms/status response).
  # `status_code` is the message's delivery state; read it with #delivered?,
  # #pending?, #failed?, or the SmsRu::Statuses constants.
  #
  # @!attribute [r] sms_id
  #   @return [String] the message id
  # @!attribute [r] status_code
  #   @return [Integer] the delivery state code (see SmsRu::Statuses)
  # @!attribute [r] status_text
  #   @return [String] the human-readable delivery state
  # @!attribute [r] cost
  #   @return [Float, nil] the message cost, when present
  class Status < Data.define(:sms_id, :status_code, :status_text, :cost)
    include DeliveryStatus

    # @param sms_id [String] the message id
    # @param hash [Hash] one entry of the response `sms` object
    # @return [SmsRu::Status]
    def self.build(sms_id, hash)
      new(
        sms_id: String(sms_id),
        status_code: Coerce.integer(hash["status_code"], Statuses::NOT_FOUND),
        status_text: Coerce.string(hash["status_text"]),
        cost: Coerce.float?(hash["cost"])
      )
    end

    # @param hash [Hash] the parsed /sms/status response
    # @return [Array<SmsRu::Status>] one Status per requested id
    def self.build_all(hash) = Coerce.records(hash["sms"]).map { |sms_id, sms| build(sms_id, sms) }

    # @return [Boolean] true when the queried id exists (not status code -1)
    def found? = status_code != Statuses::NOT_FOUND
  end

  # Per-recipient cost (one entry of a /sms/cost response).
  # `error_code`/`error_text` are populated only when this recipient cannot be priced.
  #
  # @!attribute [r] phone
  #   @return [String] the recipient's phone number
  # @!attribute [r] cost
  #   @return [Float, nil] the price for this recipient, or nil when it errored
  # @!attribute [r] sms_count
  #   @return [Integer, nil] the number of SMS segments, or nil when it errored
  # @!attribute [r] error_code
  #   @return [Integer, nil] the error code, or nil when priced
  # @!attribute [r] error_text
  #   @return [String, nil] the error reason, or nil when priced
  class CostItem < Data.define(:phone, :cost, :sms_count, :error_code, :error_text)
    # @param phone [String] the recipient's phone number
    # @param hash [Hash] one entry of the response `sms` object
    # @return [SmsRu::CostItem]
    def self.build(phone, hash)
      ok = Coerce.string(hash["status"]) == "OK"
      new(
        phone: String(phone),
        cost: Coerce.float?(hash["cost"]),
        sms_count: Coerce.integer?(hash["sms"]),
        error_code: ok ? nil : Coerce.integer(hash["status_code"]),
        error_text: ok ? nil : Coerce.string(hash["status_text"])
      )
    end

    # @return [Boolean] true when this recipient was priced successfully
    def ok? = error_code.nil?
  end

  # Result of SmsRu#cost.
  #
  # @!attribute [r] total_cost
  #   @return [Float] the total price across all recipients
  # @!attribute [r] total_sms
  #   @return [Integer] the total number of SMS segments
  # @!attribute [r] messages
  #   @return [Array<SmsRu::CostItem>] one entry per recipient
  class Cost < Data.define(:total_cost, :total_sms, :messages)
    include MessageCollection

    # @param hash [Hash] the parsed /sms/cost response
    # @return [SmsRu::Cost]
    def self.build(hash)
      messages = Coerce.records(hash["sms"]).map { |phone, cost| CostItem.build(phone, cost) }
      new(
        total_cost: Coerce.float(hash["total_cost"]),
        total_sms: Coerce.integer(hash["total_sms"]),
        messages: messages
      )
    end
  end

  # Result of SmsRu#call (flash call). `code` is the last 4 digits of the number
  # that calls the user — what they read off the incoming call and enter.
  #
  # @!attribute [r] code
  #   @return [String] the 4-digit code (the calling number's last 4 digits)
  # @!attribute [r] call_id
  #   @return [String] the call id assigned by SMS.ru
  # @!attribute [r] cost
  #   @return [Float] the price of the call
  # @!attribute [r] balance
  #   @return [Float] the account balance after the call
  class Call < Data.define(:code, :call_id, :cost, :balance)
    # @param hash [Hash] the parsed /code/call response
    # @return [SmsRu::Call]
    def self.build(hash)
      new(
        code: Coerce.string(hash["code"]),
        call_id: Coerce.string(hash["call_id"]),
        cost: Coerce.float(hash["cost"]),
        balance: Coerce.float(hash["balance"])
      )
    end
  end

  # Result of SmsRu::My#limit (daily sending limit).
  #
  # @!attribute [r] total_limit
  #   @return [Integer] the daily limit
  # @!attribute [r] used_today
  #   @return [Integer] the number of messages sent today
  class Limit < Data.define(:total_limit, :used_today)
    # @param hash [Hash] the parsed /my/limit response
    # @return [SmsRu::Limit]
    def self.build(hash)
      new(total_limit: Coerce.integer(hash["total_limit"]), used_today: Coerce.integer(hash["used_today"]))
    end

    # @return [Integer] how many more messages can be sent today
    def available_today = total_limit - used_today
  end

  # Result of SmsRu::My#free_limit (free daily messages).
  #
  # @!attribute [r] total_free
  #   @return [Integer] the daily allowance of free messages
  # @!attribute [r] used_today
  #   @return [Integer] the number used today (0 when the API omits it)
  class FreeLimit < Data.define(:total_free, :used_today)
    # @param hash [Hash] the parsed /my/free response
    # @return [SmsRu::FreeLimit]
    def self.build(hash)
      new(total_free: Coerce.integer(hash["total_free"]), used_today: Coerce.integer(hash["used_today"]))
    end

    # @return [Integer] how many free messages remain today
    def available_today = total_free - used_today
  end

  # Result of SmsRu::CallCheck#add — the number the user must call to authorize.
  #
  # @!attribute [r] check_id
  #   @return [String] the check id to poll with SmsRu::CallCheck#status
  # @!attribute [r] call_phone
  #   @return [String] the number the user must call
  # @!attribute [r] call_phone_pretty
  #   @return [String] the same number, formatted for display
  # @!attribute [r] call_phone_html
  #   @return [String] a mobile-clickable `tel:` link for the number
  class CallCheckResult < Data.define(:check_id, :call_phone, :call_phone_pretty, :call_phone_html)
    # @param hash [Hash] the parsed /callcheck/add response
    # @return [SmsRu::CallCheckResult]
    def self.build(hash)
      new(
        check_id: Coerce.string(hash["check_id"]),
        call_phone: Coerce.string(hash["call_phone"]),
        call_phone_pretty: Coerce.string(hash["call_phone_pretty"]),
        call_phone_html: Coerce.string(hash["call_phone_html"])
      )
    end
  end

  # Result of SmsRu::CallCheck#status — whether the authorizing call has arrived.
  #
  # @!attribute [r] status_code
  #   @return [Integer] the check status code (401 once confirmed)
  # @!attribute [r] status_text
  #   @return [String] the human-readable status
  class CallCheckStatus < Data.define(:status_code, :status_text)
    # @param hash [Hash] the parsed /callcheck/status response
    # @return [SmsRu::CallCheckStatus]
    def self.build(hash)
      new(status_code: Coerce.integer(hash["check_status"]), status_text: Coerce.string(hash["check_status_text"]))
    end

    # @return [Boolean] true once the user has placed the authorizing call
    def confirmed? = status_code == 401
  end

  # One stoplist entry returned by SmsRu::Stoplist#list.
  #
  # @!attribute [r] phone
  #   @return [String] the stoplisted phone number
  # @!attribute [r] note
  #   @return [String] the note you stored with the number
  class StoplistEntry < Data.define(:phone, :note)
  end
end
