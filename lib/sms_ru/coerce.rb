# frozen_string_literal: true

class SmsRu
  # Normalizes loosely-typed SMS.ru JSON values into the types the result
  # objects declare. SMS.ru is inconsistent on the wire — `/my/limit` returns
  # `total_limit` as the string `"10"` but `used_today` as the number `0`, and
  # some counters arrive as `null` — so each field is coerced here rather than
  # trusted as-is.
  #
  # Each type has two helpers: the `?` variant returns nil for a
  # missing/blank/unparseable value (for the nullable fields), while the plain
  # variant falls back to a default (`""`/`0`/`0.0`, overridable) for the fields
  # the API always populates — so call sites declare their nullability by name.
  #
  # @api private
  module Coerce
    module_function

    # @param value [Object, nil] a raw JSON value
    # @return [String, nil] the value stringified, or nil when absent
    # `?` marks the nullable variant, not a boolean predicate, so nil is intended.
    def string?(value) = value ? String(value) : nil # rubocop:disable Style/ReturnNilInPredicateMethodDefinition

    # @param value [Object, nil] a raw JSON value
    # @param default [String] returned when the value is absent
    # @return [String] the value stringified, or the default
    def string(value, default = "") = string?(value) || default

    # @param value [Object, nil] a raw JSON value (number or numeric string)
    # @return [Integer, nil] the parsed integer, or nil when absent/unparseable
    def integer?(value) = Integer(value, exception: false)

    # @param value [Object, nil] a raw JSON value (number or numeric string)
    # @param default [Integer] returned when the value is absent/unparseable
    # @return [Integer] the parsed integer, or the default
    def integer(value, default = 0) = integer?(value) || default

    # @param value [Object, nil] a raw JSON value (number or numeric string)
    # @return [Float, nil] the parsed float, or nil when absent/unparseable
    def float?(value) = Float(value, exception: false)

    # @param value [Object, nil] a raw JSON value (number or numeric string)
    # @param default [Float] returned when the value is absent/unparseable
    # @return [Float] the parsed float, or the default
    def float(value, default = 0.0) = float?(value) || default

    # @param value [Object, nil] a raw JSON value expected to be an object
    # @return [Hash] the value when it is a Hash, otherwise an empty Hash
    def records(value) = Hash.try_convert(value) || {}
  end
end
