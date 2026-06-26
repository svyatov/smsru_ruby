# frozen_string_literal: true

class SmsRu
  # Normalizes loosely-typed SMS.ru JSON values into the types the result
  # objects declare. SMS.ru is inconsistent on the wire — `/my/limit` returns
  # `total_limit` as the string `"10"` but `used_today` as the number `0`, and
  # some counters arrive as `null` — so each field is coerced here rather than
  # trusted as-is. Every helper returns nil for a missing/blank/unparseable
  # value; callers add `|| 0` / `|| ""` for the fields the API always populates.
  #
  # @api private
  module Coerce
    module_function

    # @param value [Object, nil] a raw JSON value
    # @return [String, nil] the value stringified, or nil when absent
    def string(value) = value ? String(value) : nil

    # @param value [Object, nil] a raw JSON value (number or numeric string)
    # @return [Integer, nil] the parsed integer, or nil when absent/unparseable
    def integer(value) = Integer(value, exception: false)

    # @param value [Object, nil] a raw JSON value (number or numeric string)
    # @return [Float, nil] the parsed float, or nil when absent/unparseable
    def float(value) = Float(value, exception: false)

    # @param value [Object, nil] a raw JSON value expected to be an object
    # @return [Hash] the value when it is a Hash, otherwise an empty Hash
    def records(value) = Hash.try_convert(value) || {}
  end
end
