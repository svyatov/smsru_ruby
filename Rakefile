# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"
require "steep/rake_task"
require "yard"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

RuboCop::RakeTask.new

Steep::RakeTask.new

RBS_LIBS = %w[logger json net-http uri openssl].freeze

desc "Validate RBS signatures"
task :rbs do
  sh "rbs #{RBS_LIBS.map { |lib| "-r #{lib}" }.join(" ")} -I sig validate"
end

desc "Report Steep type coverage (typed % per file)"
task "steep:stats" do
  sh "steep stats --format=table"
end

desc "Fail unless Steep reports 100% type coverage (zero untyped calls)"
task "steep:coverage" do
  rows = `steep stats --format=csv`.lines.drop(1)
  untyped = rows.sum { |line| line.split(",")[4].to_i }
  abort "Type coverage regressed: #{untyped} untyped call(s); route them through Coerce" unless untyped.zero?
  puts "Type coverage: 100% (0 untyped calls)"
end

desc "Verify actual runtime values against the RBS signatures (RBS::Test)"
task "rbs:test" do
  ENV["RBS_TEST_TARGET"] = "SmsRu::*"
  ENV["RBS_TEST_OPT"] = "-I sig #{RBS_LIBS.map { |lib| "-r #{lib}" }.join(" ")}"
  ENV["RBS_TEST_DOUBLE_SUITE"] = "minitest"
  ENV["RUBYOPT"] = "-r rbs/test/setup #{ENV.fetch("RUBYOPT", nil)}".strip
  Rake::Task[:test].invoke
end

YARD::Rake::YardocTask.new

namespace :yard do
  desc "Fail unless 100% of the public API is documented"
  task :stats do
    out = `yard stats --list-undoc`
    puts out
    abort "Undocumented public API found" unless out.include?("100.00% documented")
  end
end

namespace :vcr do
  desc "Record VCR cassettes against the live SMS.ru API (requires SMSRU_API_ID)"
  task :record do
    abort "Set SMSRU_API_ID to record cassettes (test=1 sends are free)." unless ENV["SMSRU_API_ID"]

    ENV["VCR_RECORD"] = "1"
    Rake::Task["test"].invoke
  end
end

# `rake release` (from bundler/gem_tasks) pushes the gem to RubyGems, which
# requires an MFA OTP. Feed it a fresh code from 1Password via GEM_HOST_OTP_CODE,
# which `gem push` reads. Needs `op` signed in (interactive/desktop session).
Rake::Task["release:rubygem_push"].enhance(["fetch_otp"])

task :fetch_otp do
  ENV["GEM_HOST_OTP_CODE"] = `op item get "RubyGems" --account my --otp`.strip
end

task default: %i[rubocop rbs test]
