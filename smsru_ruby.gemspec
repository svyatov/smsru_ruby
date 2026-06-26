# frozen_string_literal: true

require_relative "lib/sms_ru/version"

Gem::Specification.new do |spec|
  spec.name = "smsru_ruby"
  spec.version = SmsRu::VERSION
  spec.authors = ["Leonid Svyatov"]
  spec.email = ["leonid@svyatov.com"]

  spec.summary = "Modern, dependency-free Ruby client for the SMS.ru API."
  spec.description = "A modern, dependency-free Ruby client for the SMS.ru HTTP API. Send single or bulk SMS, " \
                     "schedule delivery, check cost and delivery status, request call-password codes, inspect " \
                     "balance/limits/senders, manage the stoplist, and register delivery callbacks."
  spec.homepage = "https://github.com/svyatov/smsru_ruby"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.require_paths = ["lib"]
  spec.files = Dir["lib/**/*.rb"] + %w[.yardopts CHANGELOG.md LICENSE.txt README.md smsru_ruby.gemspec]

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/smsru_ruby"
  spec.metadata["source_code_uri"] = "https://github.com/svyatov/smsru_ruby"
  spec.metadata["changelog_uri"] = "https://github.com/svyatov/smsru_ruby/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/svyatov/smsru_ruby/issues"
end
