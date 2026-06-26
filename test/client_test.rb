# frozen_string_literal: true

require "test_helper"

# End-to-end tests replayed from real SMS.ru responses recorded with
# `rake vcr:record` (see README); until recorded they are skipped.
#
# The recording account has no approved sender, so `deliver`/`cost` come back
# with a per-recipient error (221) while the request itself succeeds — these
# tests therefore assert that the real responses are parsed correctly, not that
# a message was actually sent. The successful-send path is covered with a stub
# in transport_test.rb. Write/charged endpoints (call, stoplist, callbacks) are
# also stubbed there.
class ClientTest < Minitest::Test
  TEST_PHONE = "79255070602"
  OTHER_PHONE = "74993221627"

  def setup
    @client = SmsRu.new(ENV.fetch("SMSRU_API_ID", "stub-api-id"), test: true)
  end

  def test_deliver_to_one_number
    with_cassette("deliver_single") do
      result = @client.deliver(TEST_PHONE, "Hello from smsru_ruby")

      assert_equal 1, result.messages.size
      assert_equal TEST_PHONE, result.messages.first.phone
    end
  end

  def test_deliver_same_text_to_many
    with_cassette("deliver_many") do
      result = @client.deliver([TEST_PHONE, OTHER_PHONE], "Hello everyone")

      assert_equal 2, result.messages.size
    end
  end

  def test_deliver_per_number_text
    with_cassette("deliver_multi") do
      result = @client.deliver({ TEST_PHONE => "First", OTHER_PHONE => "Second" })

      assert_equal 2, result.messages.size
    end
  end

  def test_cost
    with_cassette("cost") do
      cost = @client.cost(TEST_PHONE, "How much is this?")

      assert_instance_of SmsRu::Cost, cost
      assert_equal 1, cost.messages.size
    end
  end

  def test_status
    with_cassette("status") do
      status = @client.status("000000-10000000")

      refute_nil status.status_code
    end
  end

  def test_balance
    with_cassette("balance") do
      refute_nil @client.my.balance
    end
  end

  def test_limit
    with_cassette("limit") do
      limit = @client.my.limit

      refute_nil limit.total_limit
      refute_nil limit.used_today
    end
  end

  def test_free_limit
    with_cassette("free") do
      free = @client.my.free_limit

      assert_instance_of SmsRu::FreeLimit, free
      refute_nil free.total_free
    end
  end

  def test_senders
    with_cassette("senders") do
      assert_kind_of Array, @client.my.senders
    end
  end

  def test_auth_ok
    with_cassette("authed") do
      assert_predicate @client.auth, :ok?
    end
  end

  def test_callbacks_add_list_remove
    url = "https://example.com/sms/callback"

    with_cassette("callbacks") do
      assert_includes @client.callbacks.add(url), url
      assert_includes @client.callbacks.list, url
      refute_includes @client.callbacks.remove(url), url
    end
  end

  # NOTE: #call and #stoplist are intentionally not recorded — /sms/call places a
  # real billed phone call, and stoplist mutates the live account and rejects
  # placeholder numbers. They are covered deterministically in transport_test.rb.
end
