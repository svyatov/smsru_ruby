# frozen_string_literal: true

source "https://rubygems.org"

# Runtime dependencies are declared in the gemspec (there are none).
gemspec

gem "irb", require: false # for bin/console (a bundled gem since Ruby 3.4)
gem "rake", "~> 13.4"

gem "minitest", "~> 6.0"
gem "vcr", "~> 6.4"
gem "webmock", "~> 3.26"

gem "rubocop", "~> 1.88"
gem "rubocop-minitest", "~> 0.39"
# rubocop's `parallel` dep: 2.x requires Ruby >= 3.3, but the gem still supports
# 3.2. Pin below 2.0 so `bundle install` resolves on the 3.2 CI row.
gem "parallel", "< 2", require: false

gem "rbs", "~> 4.0", require: false
gem "steep", "~> 2.0", require: false

gem "yard", "~> 0.9", require: false

gem "simplecov", "~> 0.22", require: false
gem "simplecov_json_formatter", "~> 0.1", require: false
