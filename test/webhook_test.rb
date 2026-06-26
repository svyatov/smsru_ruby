# frozen_string_literal: true

require "test_helper"

class WebhookTest < Minitest::Test
  def test_parse_array_of_records
    events = SmsRu::Webhook.parse(%W[sms_status\n000000-1\n103 sms_status\n000000-2\n104])

    assert_equal 2, events.size
    assert_predicate events.first, :sms_status?
    assert_equal "000000-1", events.first.sms_id
    assert_equal 103, events.first.status_code
    assert_equal 104, events.last.status_code
  end

  def test_parse_single_string
    events = SmsRu::Webhook.parse("sms_status\n000000-9\n103")

    assert_equal 1, events.size
    assert_equal "000000-9", events.first.sms_id
  end

  def test_preserves_raw_lines
    events = SmsRu::Webhook.parse("sms_status\n000000-1\n103\nextra")

    assert_equal %w[sms_status 000000-1 103 extra], events.first.raw
  end

  def test_non_sms_status_entry
    events = SmsRu::Webhook.parse("other\nfoo")

    refute_predicate events.first, :sms_status?
    assert_nil events.first.status_code
  end

  def test_parse_nil_is_empty
    assert_empty SmsRu::Webhook.parse(nil)
  end
end
