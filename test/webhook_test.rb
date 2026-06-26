# frozen_string_literal: true

require "test_helper"

class WebhookTest < Minitest::Test
  def test_parse_sms_status_records
    events = SmsRu::Webhook.parse(%W[sms_status\n000000-1\n103\n1782469893 sms_status\n000000-2\n104\n1782469894])

    assert_equal 2, events.size
    assert_predicate events.first, :sms_status?
    assert_equal "000000-1", events.first.id
    assert_equal 103, events.first.status_code
    assert_equal Time.at(1_782_469_893), events.first.created_at
    assert_equal 104, events.last.status_code
  end

  def test_parse_callcheck_status_record
    event = SmsRu::Webhook.parse("callcheck_status\n000000-9\n402\n1782469893").first

    assert_predicate event, :callcheck_status?
    refute_predicate event, :sms_status?
    assert_equal "000000-9", event.id
    assert_equal 402, event.status_code
  end

  def test_parse_single_string
    events = SmsRu::Webhook.parse("sms_status\n000000-9\n103\n1782469893")

    assert_equal 1, events.size
    assert_equal "000000-9", events.first.id
  end

  def test_parse_rack_hash_shape_preserves_order
    # Rack turns data[1]/data[2] into a Hash, possibly out of numeric order.
    data = { "2" => "sms_status\n000000-2\n104\n1", "1" => "sms_status\n000000-1\n103\n1" }

    assert_equal %w[000000-1 000000-2], SmsRu::Webhook.parse(data).map(&:id)
  end

  def test_preserves_raw_lines
    events = SmsRu::Webhook.parse("sms_status\n000000-1\n103\n1782469893\nextra")

    assert_equal %w[sms_status 000000-1 103 1782469893 extra], events.first.raw
  end

  def test_unknown_type_is_parsed_but_not_flagged
    events = SmsRu::Webhook.parse("other\nfoo")

    refute_predicate events.first, :sms_status?
    refute_predicate events.first, :callcheck_status?
    assert_nil events.first.status_code
  end

  def test_parse_nil_is_empty
    assert_empty SmsRu::Webhook.parse(nil)
  end

  def test_valid_signature
    api_id = "secret-key"
    data = { "2" => "b", "1" => "a" }
    hash = OpenSSL::Digest.hexdigest("SHA256", "#{api_id}ab") # entries sorted: a then b

    assert SmsRu::Webhook.valid?(data, hash, api_id)
    refute SmsRu::Webhook.valid?(data, "deadbeef", api_id)
    refute SmsRu::Webhook.valid?(data, nil, api_id)
  end
end
