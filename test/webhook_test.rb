# frozen_string_literal: true

require "test_helper"

class WebhookTest < Minitest::Test
  def test_parse_sms_status_records
    events = SmsRu::Webhook.parse(%W[sms_status\n000000-1\n103\n1782469893 sms_status\n000000-2\n104\n1782469894])

    assert_equal 2, events.size
    assert_instance_of SmsRu::Events::SmsStatus, events.first
    assert_equal "000000-1", events.first.id
    assert_equal 103, events.first.status_code
    assert_predicate events.first, :delivered?
    assert_equal Time.at(1_782_469_893), events.first.created_at
    refute_predicate events.last, :delivered? # 104
  end

  def test_parse_callcheck_status_record
    confirmed = SmsRu::Webhook.parse("callcheck_status\n000000-9\n401\n1782469893").first
    expired = SmsRu::Webhook.parse("callcheck_status\n000000-8\n402\n1782469893").first

    assert_instance_of SmsRu::Events::CallcheckStatus, confirmed
    assert_equal "000000-9", confirmed.id
    assert_predicate confirmed, :confirmed?
    refute_predicate confirmed, :expired?
    assert_predicate expired, :expired?
    refute_predicate expired, :confirmed?
  end

  def test_parse_test_heartbeat
    event = SmsRu::Webhook.parse("test\n1782404811").first

    assert_instance_of SmsRu::Events::Test, event
    assert_equal "test", event.type
    assert_equal Time.at(1_782_404_811), event.created_at
  end

  # The exact payload shape observed in production: keys start at "0", and
  # heartbeat ("test") records are interleaved with real events.
  def test_parse_real_mixed_payload
    data = {
      "0" => "test\n1782404811",
      "1" => "callcheck_status\n202626-48053517\n401\n1782404881",
      "2" => "test\n1782405281",
      "3" => "callcheck_status\n202626-48054630\n401\n1782405619"
    }

    events = SmsRu::Webhook.parse(data)

    assert_equal %w[test callcheck_status test callcheck_status], events.map(&:type)
    confirmed = events.grep(SmsRu::Events::CallcheckStatus)

    assert_equal %w[202626-48053517 202626-48054630], confirmed.map(&:id)
    assert(confirmed.all?(&:confirmed?))
  end

  def test_parse_single_string
    events = SmsRu::Webhook.parse("sms_status\n000000-9\n103\n1782469893")

    assert_equal 1, events.size
    assert_equal "000000-9", events.first.id
  end

  def test_parse_rack_hash_shape_preserves_order
    # Rack turns data[0]/data[1] into a Hash, possibly out of numeric order.
    data = { "1" => "sms_status\n000000-2\n104\n1", "0" => "sms_status\n000000-1\n103\n1" }

    assert_equal %w[000000-1 000000-2], SmsRu::Webhook.parse(data).map(&:id)
  end

  def test_preserves_raw_lines
    events = SmsRu::Webhook.parse("sms_status\n000000-1\n103\n1782469893\nextra")

    assert_equal %w[sms_status 000000-1 103 1782469893 extra], events.first.raw
  end

  def test_unknown_type_falls_back
    event = SmsRu::Webhook.parse("brand_new_event\nfoo\nbar").first

    assert_instance_of SmsRu::Events::Unknown, event
    assert_equal "brand_new_event", event.type
    assert_equal %w[brand_new_event foo bar], event.raw
  end

  def test_parse_nil_is_empty
    assert_empty SmsRu::Webhook.parse(nil)
  end

  def test_valid_signature
    api_id = "secret-key"
    data = { "1" => "b", "0" => "a" }
    hash = OpenSSL::Digest.hexdigest("SHA256", "#{api_id}ab") # entries sorted: a then b

    assert SmsRu::Webhook.valid?(data, hash, api_id)
    refute SmsRu::Webhook.valid?(data, "deadbeef", api_id)
    refute SmsRu::Webhook.valid?(data, nil, api_id)
  end
end
