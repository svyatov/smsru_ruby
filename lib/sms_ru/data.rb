# frozen_string_literal: true

class SmsRu
  # A single message inside a send response (one entry of the `sms` object).
  #
  # @!attribute [r] phone
  #   @return [String] the recipient's phone number
  # @!attribute [r] sms_id
  #   @return [String, nil] the message id assigned by SMS.ru (nil on failure)
  # @!attribute [r] status
  #   @return [String] the per-recipient status ("OK" or "ERROR")
  # @!attribute [r] status_code
  #   @return [Integer] the per-recipient numeric status code
  # @!attribute [r] status_text
  #   @return [String, nil] the human-readable status text, when present
  Sms = Data.define(:phone, :sms_id, :status, :status_code, :status_text) do
    # @param phone [String] the recipient's phone number
    # @param hash [Hash] one entry of the response `sms` object
    # @return [SmsRu::Sms]
    def self.build(phone, hash)
      new(
        phone: phone,
        sms_id: hash["sms_id"],
        status: hash["status"],
        status_code: hash["status_code"],
        status_text: hash["status_text"]
      )
    end

    # @return [Boolean] true when this recipient was accepted
    def ok? = status == "OK"
  end

  # Result of SmsRu#deliver. `messages` holds one Sms per recipient; individual
  # recipients may have failed even when the overall request succeeded.
  #
  # @!attribute [r] status_code
  #   @return [Integer] the overall request status code (100 on success)
  # @!attribute [r] balance
  #   @return [Float] the account balance after the request
  # @!attribute [r] messages
  #   @return [Array<SmsRu::Sms>] one entry per recipient
  SendResult = Data.define(:status_code, :balance, :messages) do
    # @param hash [Hash] the parsed /sms/send response
    # @return [SmsRu::SendResult]
    def self.build(hash)
      messages = (hash["sms"] || {}).map { |phone, sms| Sms.build(phone, sms) }
      new(status_code: hash["status_code"], balance: hash["balance"], messages: messages)
    end
  end

  # Delivery status of one message (one entry of a /sms/status response).
  #
  # @!attribute [r] sms_id
  #   @return [String] the message id
  # @!attribute [r] status
  #   @return [String] the status ("OK" or "ERROR")
  # @!attribute [r] status_code
  #   @return [Integer] the numeric delivery status code
  # @!attribute [r] cost
  #   @return [Float, nil] the message cost, when present
  # @!attribute [r] status_text
  #   @return [String, nil] the human-readable status text, when present
  Status = Data.define(:sms_id, :status, :status_code, :cost, :status_text) do
    # @param sms_id [String] the message id
    # @param hash [Hash] one entry of the response `sms` object
    # @return [SmsRu::Status]
    def self.build(sms_id, hash)
      new(
        sms_id: sms_id,
        status: hash["status"],
        status_code: hash["status_code"],
        cost: hash["cost"],
        status_text: hash["status_text"]
      )
    end

    # @param hash [Hash] the parsed /sms/status response
    # @return [Array<SmsRu::Status>] one Status per requested id
    def self.build_all(hash) = (hash["sms"] || {}).map { |sms_id, sms| build(sms_id, sms) }

    # @return [Boolean] true when the message status is "OK"
    def ok? = status == "OK"
  end

  # Per-recipient cost (one entry of a /sms/cost response).
  #
  # @!attribute [r] phone
  #   @return [String] the recipient's phone number
  # @!attribute [r] status
  #   @return [String] the per-recipient status ("OK" or "ERROR")
  # @!attribute [r] status_code
  #   @return [Integer] the per-recipient numeric status code
  # @!attribute [r] cost
  #   @return [Float] the price for this recipient
  # @!attribute [r] sms_count
  #   @return [Integer] the number of SMS segments
  # @!attribute [r] status_text
  #   @return [String, nil] the human-readable status text, when present
  CostItem = Data.define(:phone, :status, :status_code, :cost, :sms_count, :status_text) do
    # @param phone [String] the recipient's phone number
    # @param hash [Hash] one entry of the response `sms` object
    # @return [SmsRu::CostItem]
    def self.build(phone, hash)
      new(
        phone: phone,
        status: hash["status"],
        status_code: hash["status_code"],
        cost: hash["cost"],
        sms_count: hash["sms"],
        status_text: hash["status_text"]
      )
    end

    # @return [Boolean] true when this recipient was priced successfully
    def ok? = status == "OK"
  end

  # Result of SmsRu#cost.
  #
  # @!attribute [r] total_cost
  #   @return [Float] the total price across all recipients
  # @!attribute [r] total_sms
  #   @return [Integer] the total number of SMS segments
  # @!attribute [r] messages
  #   @return [Array<SmsRu::CostItem>] one entry per recipient
  Cost = Data.define(:total_cost, :total_sms, :messages) do
    # @param hash [Hash] the parsed /sms/cost response
    # @return [SmsRu::Cost]
    def self.build(hash)
      messages = (hash["sms"] || {}).map { |phone, cost| CostItem.build(phone, cost) }
      new(total_cost: hash["total_cost"], total_sms: hash["total_sms"], messages: messages)
    end
  end

  # Result of SmsRu#call. `code` is the 4-digit code the robocall will dictate.
  #
  # @!attribute [r] code
  #   @return [String] the 4-digit authorization code dictated by the robocall
  # @!attribute [r] call_id
  #   @return [String] the call id assigned by SMS.ru
  # @!attribute [r] cost
  #   @return [Float] the price of the call
  # @!attribute [r] balance
  #   @return [Float] the account balance after the call
  Call = Data.define(:code, :call_id, :cost, :balance) do
    # @param hash [Hash] the parsed /sms/call response
    # @return [SmsRu::Call]
    def self.build(hash)
      new(code: hash["code"], call_id: hash["call_id"], cost: hash["cost"], balance: hash["balance"])
    end
  end

  # Result of SmsRu::My#limit (daily sending limit).
  #
  # @!attribute [r] total_limit
  #   @return [Integer] the daily limit
  # @!attribute [r] used_today
  #   @return [Integer] the number of messages sent today
  Limit = Data.define(:total_limit, :used_today) do
    # @param hash [Hash] the parsed /my/limit response
    # @return [SmsRu::Limit]
    def self.build(hash) = new(total_limit: hash["total_limit"].to_i, used_today: hash["used_today"].to_i)

    # @return [Integer] how many more messages can be sent today
    def available_today = total_limit - used_today
  end

  # Result of SmsRu::My#free_limit (free daily messages).
  #
  # @!attribute [r] total_free
  #   @return [Integer] the daily allowance of free messages
  # @!attribute [r] used_today
  #   @return [Integer] the number used today (0 when the API omits it)
  FreeLimit = Data.define(:total_free, :used_today) do
    # @param hash [Hash] the parsed /my/free response
    # @return [SmsRu::FreeLimit]
    def self.build(hash) = new(total_free: hash["total_free"].to_i, used_today: hash["used_today"].to_i)

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
  CallCheckResult = Data.define(:check_id, :call_phone, :call_phone_pretty, :call_phone_html) do
    # @param hash [Hash] the parsed /callcheck/add response
    # @return [SmsRu::CallCheckResult]
    def self.build(hash)
      new(
        check_id: hash["check_id"],
        call_phone: hash["call_phone"],
        call_phone_pretty: hash["call_phone_pretty"],
        call_phone_html: hash["call_phone_html"]
      )
    end
  end

  # Result of SmsRu::CallCheck#status — whether the authorizing call has arrived.
  #
  # @!attribute [r] status_code
  #   @return [Integer] the check status code (401 once confirmed)
  # @!attribute [r] status_text
  #   @return [String, nil] the human-readable status, when present
  CallCheckStatus = Data.define(:status_code, :status_text) do
    # @param hash [Hash] the parsed /callcheck/status response
    # @return [SmsRu::CallCheckStatus]
    def self.build(hash) = new(status_code: hash["check_status"], status_text: hash["check_status_text"])

    # @return [Boolean] true once the user has placed the authorizing call
    def confirmed? = status_code == 401
  end

  # One stoplist entry returned by SmsRu::Stoplist#list.
  #
  # @!attribute [r] phone
  #   @return [String] the stoplisted phone number
  # @!attribute [r] note
  #   @return [String] the note you stored with the number
  StoplistEntry = Data.define(:phone, :note)
end
