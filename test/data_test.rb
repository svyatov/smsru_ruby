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

    assert_in_delta 4122.56, result.balance
    assert_equal 2, result.messages.size

    ok = result.messages.first

    assert_equal "79255070602", ok.phone
    assert_equal "000000-10000000", ok.sms_id
    assert_predicate ok, :ok?
    assert_nil ok.error_code

    failed = result.messages.last

    refute_predicate failed, :ok?
    assert_equal 207, failed.error_code
    assert_equal "blocked", failed.error_text
  end

  def test_send_result_build_without_sms_key
    result = SmsRu::SendResult.build("status" => "OK", "balance" => 1.0)

    assert_empty result.messages
  end

  def test_send_result_partitions_and_indexes_recipients
    result = SmsRu::SendResult.build(
      "status" => "OK", "status_code" => 100, "balance" => 1.0,
      "sms" => {
        "79991111111" => { "status" => "OK", "status_code" => 100, "sms_id" => "1" },
        "79992222222" => { "status" => "ERROR", "status_code" => 207 }
      }
    )

    refute_predicate result, :ok? # one recipient failed
    assert_equal ["79991111111"], result.ok.map(&:phone)
    assert_equal ["79992222222"], result.failed.map(&:phone)
  end

  def test_send_result_ok_when_every_recipient_succeeds
    result = SmsRu::SendResult.build(
      "status" => "OK", "balance" => 1.0,
      "sms" => { "79991111111" => { "status" => "OK", "status_code" => 100, "sms_id" => "1" } }
    )

    assert_predicate result, :ok?
  end

  def test_cost_partitions_recipients
    cost = SmsRu::Cost.build(
      "total_cost" => 1.0, "total_sms" => 1,
      "sms" => {
        "79991111111" => { "status" => "OK", "status_code" => 100, "cost" => 1.0, "sms" => 1 },
        "79992222222" => { "status" => "ERROR", "status_code" => 207, "status_text" => "blocked" }
      }
    )

    refute_predicate cost, :ok?
    assert_equal ["79991111111"], cost.ok.map(&:phone)
    assert_equal ["79992222222"], cost.failed.map(&:phone)
    assert_equal 207, cost.failed.first.error_code
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
    assert_predicate cost.messages.first, :ok?
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
    assert_predicate statuses.first, :delivered?
    assert_predicate statuses.first, :found?
  end

  def test_status_not_found
    status = SmsRu::Status.build("bogus", "status_code" => SmsRu::Statuses::NOT_FOUND)

    refute_predicate status, :found?
    refute_predicate status, :delivered?
  end

  def test_status_state_predicates
    assert_equal 103, SmsRu::Statuses::DELIVERED

    delivered = SmsRu::Status.build("1", "status" => "OK", "status_code" => SmsRu::Statuses::DELIVERED)
    pending   = SmsRu::Status.build("2", "status" => "OK", "status_code" => SmsRu::Statuses::IN_TRANSIT)
    failed    = SmsRu::Status.build("3", "status" => "OK", "status_code" => SmsRu::Statuses::REJECTED)
    read      = SmsRu::Status.build("4", "status" => "OK", "status_code" => SmsRu::Statuses::READ)

    assert_predicate delivered, :delivered?
    assert_predicate pending, :pending?
    assert_predicate failed, :failed?
    refute_predicate delivered, :pending?
    refute_predicate failed, :delivered?
    # READ (110) is a known terminal state but deliberately in no group.
    refute(read.delivered? || read.pending? || read.failed?)
  end

  def test_scalar_builds_coerce_to_integers_and_compute_available
    limit = SmsRu::Limit.build("total_limit" => "100", "used_today" => 7) # API sends total as a String

    assert_equal [100, 7], [limit.total_limit, limit.used_today]
    assert_equal 93, limit.available_today

    free = SmsRu::FreeLimit.build("total_free" => 5, "used_today" => nil) # API may omit used_today

    assert_equal [5, 0], [free.total_free, free.used_today]
    assert_equal 5, free.available_today
  end

  def test_call_build
    call = SmsRu::Call.build("code" => "1435", "call_id" => "000000-1", "cost" => 0.4, "balance" => 10.0)

    assert_equal "1435", call.code
    assert_equal "000000-1", call.call_id
    assert_in_delta 0.4, call.cost
    assert_in_delta 10.0, call.balance
  end

  def test_data_value_equality_and_to_h
    one = SmsRu::Limit.build("total_limit" => 1, "used_today" => 0)
    two = SmsRu::Limit.build("total_limit" => 1, "used_today" => 0)

    assert_equal one, two
    assert_equal({ total_limit: 1, used_today: 0 }, one.to_h)
  end
end
