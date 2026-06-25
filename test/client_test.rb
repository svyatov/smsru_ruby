# frozen_string_literal: true

require "test_helper"

# End-to-end happy paths replayed from real SMS.ru responses. Cassettes are
# recorded with `rake vcr:record` (see README); until then these are skipped.
class ClientTest < Minitest::Test
  TEST_PHONE = "79255070602"
  OTHER_PHONE = "74993221627"

  def setup
    @client = SmsRu.new(ENV.fetch("SMSRU_API_ID", "stub-api-id"), test: true)
  end

  def test_deliver_to_one_number
    with_cassette("deliver_single") do
      result = @client.deliver(TEST_PHONE, "Hello from sms_ru_ruby")

      assert_equal 100, result.status_code
      assert_predicate result.messages.first, :ok?
      refute_nil result.messages.first.sms_id
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
      result = @client.deliver(TEST_PHONE => "First", OTHER_PHONE => "Second")

      assert_equal 2, result.messages.size
    end
  end

  def test_cost
    with_cassette("cost") do
      cost = @client.cost(TEST_PHONE, "How much is this?")

      assert_operator cost.total_sms, :>=, 1
      refute_nil cost.total_cost
    end
  end

  def test_status
    with_cassette("status") do
      status = @client.status("000000-10000000")

      refute_nil status.status_code
    end
  end

  def test_call
    with_cassette("call") do
      result = @client.call(TEST_PHONE)

      refute_nil result.code
      refute_nil result.call_id
    end
  end

  def test_balance
    with_cassette("balance") do
      refute_nil @client.balance.balance
    end
  end

  def test_limit
    with_cassette("limit") do
      limit = @client.limit

      refute_nil limit.total_limit
      refute_nil limit.used_today
    end
  end

  def test_free
    with_cassette("free") do
      free = @client.free

      refute_nil free.total_free
      refute_nil free.used_today
    end
  end

  def test_senders
    with_cassette("senders") do
      assert_kind_of Array, @client.senders
    end
  end

  def test_authed_true
    with_cassette("authed") do
      assert_predicate @client, :authed?
    end
  end

  def test_stoplist_roundtrip
    with_cassette("stoplist") do
      assert @client.stoplist.add(OTHER_PHONE, note: "test")
      assert_kind_of Array, @client.stoplist.list
      assert @client.stoplist.remove(OTHER_PHONE)
    end
  end

  def test_callbacks_roundtrip
    with_cassette("callbacks") do
      assert_kind_of Array, @client.callbacks.add("https://example.com/callback")
      assert_kind_of Array, @client.callbacks.list
      assert_kind_of Array, @client.callbacks.remove("https://example.com/callback")
    end
  end
end
