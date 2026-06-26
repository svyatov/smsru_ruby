# frozen_string_literal: true

require "test_helper"
require "logger"
require "stringio"

# Deterministic HTTP behavior that cannot be (or need not be) recorded from the
# live API: transport failures, retries, error-code mapping, and request shape.
class TransportTest < Minitest::Test
  SEND_URL = "https://sms.ru/sms/send?json=1"
  BALANCE_URL = "https://sms.ru/my/balance?json=1"
  OK_SEND = '{"status":"OK","status_code":100,"balance":1.0,"sms":{}}'
  OK_BALANCE = '{"status":"OK","status_code":100,"balance":10.0}'

  def setup
    @client = SmsRu.new("api-id", retries: 2)
  end

  def test_raises_connection_error_after_exhausting_retries
    stub = stub_request(:post, BALANCE_URL).to_timeout

    assert_raises(SmsRu::ConnectionError) { @client.my.balance }
    assert_requested stub, times: 3 # 1 initial + 2 retries
  end

  def test_retries_then_succeeds
    stub_request(:post, BALANCE_URL).to_timeout.then.to_return(body: OK_BALANCE)

    assert_in_delta 10.0, @client.my.balance
  end

  def test_retries_disabled_makes_single_attempt
    client = SmsRu.new("api-id", retries: 0)
    stub = stub_request(:post, BALANCE_URL).to_timeout

    assert_raises(SmsRu::ConnectionError) { client.my.balance }
    assert_requested stub, times: 1
  end

  def test_invalid_json_raises_connection_error_without_retry
    stub = stub_request(:post, BALANCE_URL).to_return(body: "<html>maintenance</html>")

    assert_raises(SmsRu::ConnectionError) { @client.my.balance }
    assert_requested stub, times: 1
  end

  def test_missing_status_raises_connection_error
    stub_request(:post, BALANCE_URL).to_return(body: '{"foo":"bar"}')

    assert_raises(SmsRu::ConnectionError) { @client.my.balance }
  end

  def test_auth_error_mapping
    stub_request(:post, BALANCE_URL)
      .to_return(body: '{"status":"ERROR","status_code":200,"status_text":"Wrong api_id"}')

    error = assert_raises(SmsRu::AuthError) { @client.my.balance }
    assert_equal 200, error.code
    assert_equal "Wrong api_id", error.text
  end

  def test_insufficient_funds_mapping
    stub_request(:post, SEND_URL)
      .to_return(body: '{"status":"ERROR","status_code":201,"status_text":"No money"}')

    assert_raises(SmsRu::InsufficientFundsError) { @client.deliver("79991234567", "hi") }
  end

  def test_generic_response_error_mapping
    stub_request(:post, SEND_URL)
      .to_return(body: '{"status":"ERROR","status_code":205,"status_text":"Too long"}')

    error = assert_raises(SmsRu::ResponseError) { @client.deliver("79991234567", "hi") }
    assert_equal 205, error.code
    refute_instance_of SmsRu::AuthError, error
  end

  def test_response_error_uses_default_text_when_absent
    stub_request(:post, BALANCE_URL).to_return(body: '{"status":"ERROR","status_code":999}')

    error = assert_raises(SmsRu::ResponseError) { @client.my.balance }
    assert_equal "SMS.ru returned an error", error.text
  end

  def test_deliver_parses_send_result_end_to_end
    body = '{"status":"OK","status_code":100,"balance":4122.56,' \
           '"sms":{"79991234567":{"status":"OK","status_code":100,"sms_id":"000000-1"}}}'
    stub_request(:post, SEND_URL).to_return(body: body)

    result = @client.deliver("79991234567", "hi")

    assert_in_delta 4122.56, result.balance
    assert_equal "000000-1", result.messages.first.sms_id
    assert_predicate result.messages.first, :ok?
  end

  # /code/call places a real, billed phone call (no test mode), so it is covered
  # with a stub rather than a recorded cassette.
  def test_call_returns_code
    body = '{"status":"OK","status_code":100,"code":"1435","call_id":"000000-1","cost":0.4,"balance":10.0}'
    stub_request(:post, "https://sms.ru/code/call?json=1").to_return(body: body)

    result = @client.call("79991234567")

    assert_equal "1435", result.code
    assert_equal "000000-1", result.call_id
    assert_requested(:post, "https://sms.ru/code/call?json=1") do |req|
      body = URI.decode_www_form(req.body).to_h
      body["phone"] == "79991234567" && body["ip"] == "-1"
    end
  end

  # #callcheck registers a real authorization check against a live number, so it
  # is covered with stubs rather than recorded cassettes.
  def test_callcheck_add_then_status
    stub_request(:post, "https://sms.ru/callcheck/add?json=1")
      .to_return(body: '{"status":"OK","status_code":100,"check_id":"a1b2","call_phone":"78005008275",' \
                       '"call_phone_pretty":"+7 (800) 500-8275","call_phone_html":"<a>call</a>"}')
    stub_request(:post, "https://sms.ru/callcheck/status?json=1")
      .to_return(body: '{"status":"OK","status_code":100,"check_status":401,"check_status_text":"Подтвержден"}')

    check = @client.callcheck.add("79991234567")

    assert_equal "a1b2", check.check_id
    assert_equal "+7 (800) 500-8275", check.call_phone_pretty
    assert_predicate @client.callcheck.status(check.check_id), :confirmed?
  end

  # #stoplist mutates the live account and rejects placeholder numbers, so it is
  # covered with stubs rather than recorded cassettes.
  def test_stoplist_add_list_remove
    stub_request(:post, "https://sms.ru/stoplist/add?json=1").to_return(body: '{"status":"OK","status_code":100}')
    stub_request(:post, "https://sms.ru/stoplist/del?json=1").to_return(body: '{"status":"OK","status_code":100}')
    stub_request(:post, "https://sms.ru/stoplist/get?json=1")
      .to_return(body: '{"status":"OK","status_code":100,"stoplist":{"79991234567":"spam"}}')

    assert @client.stoplist.add("79991234567", note: "spam")
    entry = @client.stoplist.list.first

    assert_equal "79991234567", entry.phone
    assert_equal "spam", entry.note
    assert @client.stoplist.remove("79991234567")
  end

  def test_auth_ok_when_api_id_valid
    stub_request(:post, "https://sms.ru/auth/check?json=1").to_return(body: '{"status":"OK","status_code":100}')

    assert_predicate @client.auth, :ok?
  end

  def test_auth_not_ok_on_auth_error
    stub_request(:post, "https://sms.ru/auth/check?json=1")
      .to_return(body: '{"status":"ERROR","status_code":200,"status_text":"Wrong api_id"}')

    refute_predicate @client.auth, :ok?
  end

  def test_deliver_array_joins_recipients_with_same_text
    stub_request(:post, SEND_URL).to_return(body: OK_SEND)

    @client.deliver(%w[79991234567 79991234568], "hi")

    assert_requested(:post, SEND_URL) do |req|
      body = URI.decode_www_form(req.body).to_h
      body["to"] == "79991234567,79991234568" && body["msg"] == "hi" && body["api_id"] == "api-id"
    end
  end

  def test_deliver_hash_builds_multi_params
    stub_request(:post, SEND_URL).to_return(body: OK_SEND)

    @client.deliver({ "79991234567" => "A", "79991234568" => "B" })

    assert_requested(:post, SEND_URL) do |req|
      body = URI.decode_www_form(req.body).to_h
      body["multi[79991234567]"] == "A" && body["multi[79991234568]"] == "B"
    end
  end

  def test_options_are_encoded
    stub_request(:post, SEND_URL).to_return(body: OK_SEND)

    @client.deliver("79991234567", "hi", from: "Company", translit: true, time: 1_280_307_978, ttl: 60, daytime: true)

    assert_requested(:post, SEND_URL) do |req|
      body = URI.decode_www_form(req.body).to_h
      body["from"] == "Company" && body["translit"] == "1" && body["time"] == "1280307978" &&
        body["ttl"] == "60" && body["daytime"] == "1"
    end
  end

  def test_global_test_mode_is_applied
    stub_request(:post, SEND_URL).to_return(body: OK_SEND)
    SmsRu.new("api-id", test: true).deliver("79991234567", "hi")

    assert_requested(:post, SEND_URL) { |req| URI.decode_www_form(req.body).to_h["test"] == "1" }
  end

  def test_per_call_test_false_overrides_global_true
    stub_request(:post, SEND_URL).to_return(body: OK_SEND)
    SmsRu.new("api-id", test: true).deliver("79991234567", "hi", test: false)

    assert_requested(:post, SEND_URL) { |req| !URI.decode_www_form(req.body).to_h.key?("test") }
  end

  def test_client_default_from_is_applied
    stub_request(:post, SEND_URL).to_return(body: OK_SEND)
    SmsRu.new("api-id", from: "Acme").deliver("79991234567", "hi")

    assert_requested(:post, SEND_URL) { |req| URI.decode_www_form(req.body).to_h["from"] == "Acme" }
  end

  def test_per_call_from_overrides_client_default
    stub_request(:post, SEND_URL).to_return(body: OK_SEND)
    SmsRu.new("api-id", from: "Acme").deliver("79991234567", "hi", from: "Other")

    assert_requested(:post, SEND_URL) { |req| URI.decode_www_form(req.body).to_h["from"] == "Other" }
  end

  def test_logger_records_request_path_but_not_secrets
    io = StringIO.new
    client = SmsRu.new("secret-api-id", logger: Logger.new(io))
    stub_request(:post, BALANCE_URL).to_return(body: OK_BALANCE)

    client.my.balance

    assert_includes io.string, "/my/balance"
    refute_includes io.string, "secret-api-id"
  end

  def test_logger_warns_on_transport_failure
    io = StringIO.new
    client = SmsRu.new("api-id", retries: 0, logger: Logger.new(io))
    stub_request(:post, BALANCE_URL).to_timeout

    assert_raises(SmsRu::ConnectionError) { client.my.balance }
    assert_match(/failed/, io.string)
  end
end
