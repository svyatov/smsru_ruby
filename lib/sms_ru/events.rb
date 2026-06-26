# frozen_string_literal: true

class SmsRu
  # Typed events decoded from an inbound SMS.ru webhook payload. One of these is
  # produced per record by SmsRu::Webhook.parse.
  module Events
    # A delivery-status notification (record type "sms_status").
    #
    # @!attribute [r] id
    #   @return [String] the message id
    # @!attribute [r] status_code
    #   @return [Integer, nil] the delivery status code (per /sms/status)
    # @!attribute [r] created_at
    #   @return [Time, nil] when SMS.ru created the status
    # @!attribute [r] raw
    #   @return [Array<String>] every line of the original record
    SmsStatus = Data.define(:id, :status_code, :created_at, :raw) do
      include DeliveryStatus

      # @return [String] the wire record type
      def type = "sms_status"
    end

    # A call-authorization notification (record type "callcheck_status").
    #
    # @!attribute [r] id
    #   @return [String] the check id (the one returned by SmsRu::CallCheck#add)
    # @!attribute [r] status_code
    #   @return [Integer, nil] the check status code (per /callcheck/status)
    # @!attribute [r] created_at
    #   @return [Time, nil] when SMS.ru created the status
    # @!attribute [r] raw
    #   @return [Array<String>] every line of the original record
    CallcheckStatus = Data.define(:id, :status_code, :created_at, :raw) do
      # @return [String] the wire record type
      def type = "callcheck_status"

      # @return [Boolean] true when the user placed the authorizing call (code 401)
      def confirmed? = status_code == 401

      # @return [Boolean] true when the authorization window elapsed (code 402)
      def expired? = status_code == 402
    end

    # SMS.ru's periodic heartbeat record (record type "test").
    #
    # @!attribute [r] created_at
    #   @return [Time, nil] when SMS.ru sent the heartbeat
    # @!attribute [r] raw
    #   @return [Array<String>] every line of the original record
    Test = Data.define(:created_at, :raw) do
      # @return [String] the wire record type
      def type = "test"
    end

    # Any record type this gem does not model explicitly. `raw` keeps every line.
    #
    # @!attribute [r] type
    #   @return [String] the wire record type
    # @!attribute [r] raw
    #   @return [Array<String>] every line of the original record
    Unknown = Data.define(:type, :raw)
  end
end
