# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"

  if ENV["CI"]
    require "simplecov_json_formatter"
    SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
  end

  SimpleCov.start do
    add_filter "/test/"
    minimum_coverage 100
  end
end

require "minitest/autorun"
require "vcr"
require "webmock/minitest"

require "smsru_ruby"

VCR.configure do |config|
  config.cassette_library_dir = "test/cassettes"
  config.hook_into :webmock
  config.default_cassette_options = { record: ENV["VCR_RECORD"] ? :new_episodes : :none }
  config.filter_sensitive_data("<API_ID>") { ENV.fetch("SMSRU_API_ID", "stub-api-id") }

  # Scrub the live account balance out of recorded responses.
  config.before_record do |interaction|
    interaction.response.body = interaction.response.body.gsub(/("balance":\s*)[\d.]+/, '\11000.0')
  end
end

# Wraps a VCR cassette but skips the example when the cassette has not been
# recorded yet, so the suite stays green before `rake vcr:record` is run.
module CassetteHelper
  CASSETTE_DIR = "test/cassettes"

  def with_cassette(name, &)
    unless ENV["VCR_RECORD"] || File.exist?(File.join(CASSETTE_DIR, "#{name}.yml"))
      skip "cassette '#{name}' not recorded yet — run `rake vcr:record`"
    end

    VCR.use_cassette(name, &)
  end
end

module Minitest
  class Test
    include CassetteHelper
  end
end
