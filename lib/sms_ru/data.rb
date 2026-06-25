# frozen_string_literal: true

class SmsRu
  # A single message inside a send response (one entry of the `sms` object).
  Sms = Data.define(:phone, :sms_id, :status, :status_code, :status_text) do
    def self.build(phone, hash)
      new(
        phone: phone,
        sms_id: hash["sms_id"],
        status: hash["status"],
        status_code: hash["status_code"],
        status_text: hash["status_text"]
      )
    end

    def ok? = status == "OK"
  end

  # Result of SmsRu#deliver. `messages` holds one Sms per recipient; individual
  # recipients may have failed even when the overall request succeeded.
  SendResult = Data.define(:status_code, :balance, :messages) do
    def self.build(hash)
      messages = (hash["sms"] || {}).map { |phone, sms| Sms.build(phone, sms) }
      new(status_code: hash["status_code"], balance: hash["balance"], messages: messages)
    end
  end

  # Delivery status of one message (one entry of a /sms/status response).
  Status = Data.define(:sms_id, :status, :status_code, :cost, :status_text) do
    def self.build(sms_id, hash)
      new(
        sms_id: sms_id,
        status: hash["status"],
        status_code: hash["status_code"],
        cost: hash["cost"],
        status_text: hash["status_text"]
      )
    end

    def self.build_all(hash) = (hash["sms"] || {}).map { |sms_id, sms| build(sms_id, sms) }

    def ok? = status == "OK"
  end

  # Per-recipient cost (one entry of a /sms/cost response).
  CostItem = Data.define(:phone, :status, :status_code, :cost, :sms_count, :status_text) do
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
  end

  # Result of SmsRu#cost.
  Cost = Data.define(:total_cost, :total_sms, :messages) do
    def self.build(hash)
      messages = (hash["sms"] || {}).map { |phone, cost| CostItem.build(phone, cost) }
      new(total_cost: hash["total_cost"], total_sms: hash["total_sms"], messages: messages)
    end
  end

  # Result of SmsRu#call. `code` is the 4-digit code the robocall will dictate.
  Call = Data.define(:code, :call_id, :cost, :balance) do
    def self.build(hash)
      new(code: hash["code"], call_id: hash["call_id"], cost: hash["cost"], balance: hash["balance"])
    end
  end

  # Result of SmsRu#balance.
  Balance = Data.define(:balance) do
    def self.build(hash) = new(balance: hash["balance"])
  end

  # Result of SmsRu#limit (daily sending limit).
  Limit = Data.define(:total_limit, :used_today) do
    def self.build(hash) = new(total_limit: hash["total_limit"], used_today: hash["used_today"])
  end

  # Result of SmsRu#free (free daily messages).
  Free = Data.define(:total_free, :used_today) do
    def self.build(hash) = new(total_free: hash["total_free"], used_today: hash["used_today"])
  end

  # One stoplist entry returned by SmsRu::Stoplist#list.
  StoplistEntry = Data.define(:phone, :note)
end
