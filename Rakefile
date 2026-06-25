# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"
require "yard"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

RuboCop::RakeTask.new

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

task default: %i[rubocop test]
