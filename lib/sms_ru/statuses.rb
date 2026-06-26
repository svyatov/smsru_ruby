# frozen_string_literal: true

class SmsRu
  # Delivery status codes returned by /sms/status and carried in `sms_status`
  # webhooks. See https://sms.ru/api/status for the authoritative list.
  module Statuses
    # The message id was not found.
    NOT_FOUND = -1
    # Accepted and waiting in the SMS.ru queue.
    QUEUED = 100
    # Being transmitted to the mobile operator.
    SENT_TO_OPERATOR = 101
    # Handed to the operator; in transit to the handset.
    IN_TRANSIT = 102
    # Delivered to the handset.
    DELIVERED = 103
    # Not delivered: the message's time-to-live expired.
    EXPIRED = 104
    # Not delivered: deleted by the operator.
    DELETED = 105
    # Not delivered: handset malfunction.
    PHONE_FAILURE = 106
    # Not delivered: unknown reason.
    UNKNOWN_FAILURE = 107
    # Not delivered: rejected by the operator.
    REJECTED = 108
    # Delivered and read (where the channel reports it).
    READ = 110
    # Not delivered: no route to the number.
    NO_ROUTE = 150

    # Codes for a message still on its way (no final outcome yet).
    PENDING = [QUEUED, SENT_TO_OPERATOR, IN_TRANSIT].freeze
    # Codes for a message that will not be delivered.
    FAILED = [EXPIRED, DELETED, PHONE_FAILURE, UNKNOWN_FAILURE, REJECTED, NO_ROUTE].freeze
  end

  # Delivery-state predicates shared by SmsRu::Status and
  # SmsRu::Events::SmsStatus. The including object must expose `status_code`.
  module DeliveryStatus
    # @return [Boolean] true once the message reached the handset (code 103)
    def delivered? = status_code == Statuses::DELIVERED

    # @return [Boolean] true while the message is still in transit (codes 100–102)
    def pending? = !status_code.nil? && Statuses::PENDING.include?(status_code)

    # @return [Boolean] true when the message will not be delivered (codes 104–108, 150)
    def failed? = !status_code.nil? && Statuses::FAILED.include?(status_code)
  end
end
