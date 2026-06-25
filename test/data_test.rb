# frozen_string_literal: true

require "test_helper"

# Exercises the response -> Data mapping with the exact JSON shapes documented
# at https://sms.ru/api. Pure Ruby, no network.
class DataTest < Minitest::Test
  def test_send_result_build
    hash = {
      "status" => "OK", "status_code" => 100, "balance" => 4122.56,
      "sms" => {
        "79255070602" => { "status" => "OK", "status_code" => 100, "sms_id" => "000000-10000000" },
        "74993221627" => { "status" => "ERROR", "status_code" => 207, "status_text" => "blocked" }
      }
    }

    result = SmsRu::SendResult.build(hash)

    assert_equal 100, result.status_code
    assert_in_delta 4122.56, result.balance
    assert_equal 2, result.messages.size

    ok = result.messages.first

    assert_equal "79255070602", ok.phone
    assert_equal "000000-10000000", ok.sms_id
    assert_predicate ok, :ok?

    failed = result.messages.last

    refute_predicate failed, :ok?
    assert_equal "blocked", failed.status_text
  end

  def test_send_result_build_without_sms_key
    result = SmsRu::SendResult.build("status" => "OK", "status_code" => 100, "balance" => 1.0)

    assert_empty result.messages
  end

  def test_cost_build
    hash = {
      "status" => "OK", "status_code" => 100, "total_cost" => 1.74, "total_sms" => 2,
      "sms" => { "79255070602" => { "status" => "OK", "status_code" => 100, "cost" => 1.74, "sms" => 2 } }
    }

    cost = SmsRu::Cost.build(hash)

    assert_in_delta 1.74, cost.total_cost
    assert_equal 2, cost.total_sms
    assert_in_delta 1.74, cost.messages.first.cost
    assert_equal 2, cost.messages.first.sms_count
  end

  def test_status_build_all
    hash = {
      "sms" => {
        "000000-000001" => { "status" => "OK", "status_code" => 103, "cost" => 0.5, "status_text" => "Доставлено" }
      }
    }

    statuses = SmsRu::Status.build_all(hash)

    assert_equal 1, statuses.size
    assert_equal "000000-000001", statuses.first.sms_id
    assert_equal 103, statuses.first.status_code
    assert_predicate statuses.first, :ok?
  end

  def test_scalar_builds
    assert_in_delta 4762.58, SmsRu::Balance.build("balance" => 4762.58).balance

    limit = SmsRu::Limit.build("total_limit" => 100, "used_today" => 7)

    assert_equal [100, 7], [limit.total_limit, limit.used_today]

    free = SmsRu::Free.build("total_free" => 5, "used_today" => 3)

    assert_equal [5, 3], [free.total_free, free.used_today]
  end

  def test_call_build
    call = SmsRu::Call.build("code" => "1435", "call_id" => "000000-1", "cost" => 0.4, "balance" => 10.0)

    assert_equal "1435", call.code
    assert_equal "000000-1", call.call_id
    assert_in_delta 0.4, call.cost
    assert_in_delta 10.0, call.balance
  end

  def test_data_value_equality_and_to_h
    one = SmsRu::Balance.build("balance" => 1.0)
    two = SmsRu::Balance.build("balance" => 1.0)

    assert_equal one, two
    assert_equal({ balance: 1.0 }, one.to_h)
  end
end
