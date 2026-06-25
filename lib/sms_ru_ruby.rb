# frozen_string_literal: true

# The gem is named `sms_ru_ruby`; the library is required as `sms_ru`.
# This shim keeps `require "sms_ru_ruby"` and Bundler's auto-require working.
require_relative "sms_ru"
