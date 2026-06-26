# smsru_ruby

[![Gem Version](https://badge.fury.io/rb/smsru_ruby.svg)](https://rubygems.org/gems/smsru_ruby)
[![CI](https://github.com/svyatov/smsru_ruby/actions/workflows/main.yml/badge.svg)](https://github.com/svyatov/smsru_ruby/actions/workflows/main.yml)

A modern, dependency-free Ruby client for the [SMS.ru](https://sms.ru) HTTP API.

It is a clean, idiomatic Ruby port of the official [SMS.ru PHP library](https://sms.ru/php):
send single or bulk SMS, schedule delivery, check cost and delivery status, request
verify users by phone call, inspect your balance/limits/senders, manage the stoplist, and
register delivery callbacks — all returning typed, immutable result objects and
raising typed errors.

- **Zero runtime dependencies** — just Ruby's standard library (`net/http`, `json`).
- **Typed results** — immutable `Data` objects, not raw hashes.
- **Typed errors** — `rescue SmsRu::Error` to catch everything.
- **TLS verified** by default, with configurable timeout and retries.

## Table of contents

- [Supported Ruby versions](#supported-ruby-versions)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Configuration](#configuration)
- [Sending messages](#sending-messages)
- [Cost and status](#cost-and-status)
- [Verify by phone call](#verify-by-phone-call)
- [Account information](#account-information)
- [Stoplist](#stoplist)
- [Callbacks (webhooks)](#callbacks-webhooks)
- [Error handling](#error-handling)
- [Development](#development)
- [Recording test cassettes](#recording-test-cassettes)
- [License](#license)

## Supported Ruby versions

Ruby **3.2+** (the result objects use [`Data`](https://docs.ruby-lang.org/en/3.2/Data.html)).
CI runs against `ruby-head`, `4.0`, `3.4`, `3.3`, and `3.2`.

## Installation

```ruby
# Gemfile
gem "smsru_ruby"
```

```sh
bundle install
# or
gem install smsru_ruby
```

```ruby
require "smsru_ruby"
```

## Quick start

```ruby
client = SmsRu.new("YOUR_API_ID")

result = client.deliver("79991234567", "Hello from Ruby!")
result.messages.first.sms_id   # => "000000-10000000"
client.my.balance              # => 4762.58
```

Get your `api_id` in the SMS.ru dashboard under
[Settings → API](https://sms.ru/?panel=api).

## Configuration

```ruby
SmsRu.new(
  "YOUR_API_ID",
  timeout: 30,   # open/read timeout in seconds (default: 30)
  test: false,   # when true, every `deliver` defaults to test mode (no charge)
  retries: 5     # retries on transport failure; 0 disables (default: 5, matching the PHP lib)
)
```

Retries apply only to transport-level problems (timeouts, refused connections).
API errors are never retried — they are raised immediately.

## Sending messages

`#deliver` accepts the recipient(s) in three shapes:

```ruby
# 1. One number
client.deliver("79991234567", "Hi there")

# 2. Same text to many numbers (Array)
client.deliver(["79991234567", "79991234568"], "Hi everyone")

# 3. A different text per number (Hash — do not pass a separate text).
#    Use braces so Ruby treats it as a positional Hash, not keyword arguments.
client.deliver({
  "79991234567" => "Hi Alice",
  "79991234568" => "Hi Bob"
})
```

Optional keyword arguments (all optional):

```ruby
client.deliver(
  "79991234567", "Hi",
  from: "MyCompany",     # approved sender name
  time: Time.now.to_i + 3600, # scheduled send (UNIX time, up to 2 months ahead)
  ttl: 60,               # message lifetime in minutes (1–1440)
  daytime: true,         # defer night-time sends to the recipient's daytime
  translit: true,        # transliterate Cyrillic to Latin
  test: true,            # test mode for this call (overrides the client default)
  ip: "192.0.2.1",       # end-user IP (for auth-code anti-fraud)
  partner_id: 12345      # partner program id
)
```

The result is a `SmsRu::SendResult`. Individual recipients can fail even when the
overall request succeeds, so inspect each message:

```ruby
result = client.deliver(["79991234567", "74993221627"], "Hi")
result.status_code              # => 100
result.balance                 # => 4122.56
result.messages.each do |sms|
  if sms.ok?
    puts "#{sms.phone}: sent as #{sms.sms_id}"
  else
    puts "#{sms.phone}: failed (#{sms.status_code}) #{sms.status_text}"
  end
end
```

## Cost and status

```ruby
# Price a message before sending (text is optional; omit it for the price of 1 SMS)
cost = client.cost("79991234567", "How much?")
cost.total_cost  # => 1.74
cost.total_sms   # => 2

# Delivery status — one id or an Array of ids
status = client.status("000000-10000000")
status.status_code  # => 103
status.status_text  # => "Сообщение доставлено"

statuses = client.status(["000000-10000000", "000000-10000001"]) # => [SmsRu::Status, ...]
```

## Verify by phone call

Two ways to verify a user by phone call — no SMS required.

**Outbound (flash call).** SMS.ru calls the user; the last 4 digits of the
calling number are the code. You receive the expected `code` to compare against
what the user enters:

```ruby
call = client.call("79991234567")
call.code     # => "1435" — the last 4 digits the user will see
call.call_id  # => "000000-10000000"
```

**Inbound (callcheck).** The user calls a number you show them; SMS.ru drops the
call (free for the caller) and marks the check confirmed:

```ruby
check = client.callcheck.add("79991234567")
check.call_phone_pretty  # => "+7 (800) 500-8275" — show this to the user

# Poll until the user has called (or receive it via a callback/webhook):
client.callcheck.status(check.check_id).confirmed?  # => true
```

## Account information

Account reads are grouped under `client.my`:

```ruby
client.my.balance          # => 4762.58 (a Float)

limit = client.my.limit
limit.total_limit          # => 100
limit.used_today           # => 7
limit.available_today      # => 93

free = client.my.free_limit
free.total_free            # => 5
free.used_today            # => 3
free.available_today       # => 2

client.my.senders          # => ["MyCompany", "AnotherName"]
```

Check that the configured `api_id` is valid:

```ruby
client.auth.ok?            # => true
```

## Stoplist

Numbers on the stoplist never receive messages and are never charged.

```ruby
client.stoplist.add("79991234567", note: "spam complaint") # => true
client.stoplist.list   # => [#<data SmsRu::StoplistEntry phone="79991234567", note="spam complaint">]
client.stoplist.remove("79991234567") # => true
```

## Callbacks (webhooks)

Register URLs that SMS.ru will POST delivery and call-authorization statuses to.
Each method returns the full list of registered URLs:

```ruby
client.callbacks.add("https://example.com/sms/callback") # => ["https://example.com/sms/callback"]
client.callbacks.list   # => [...]
client.callbacks.remove("https://example.com/sms/callback") # => [...]
```

In your webhook handler, verify the signature, parse the payload, and
acknowledge it by replying with the string `"100"`:

```ruby
# Reject forged callbacks: SMS.ru signs every payload with your api_id.
unless SmsRu::Webhook.valid?(params["data"], params["hash"], "YOUR_API_ID")
  return head(:forbidden)
end

# SMS.ru sends up to 100 records as POST fields data[0]..data[N]
# (a Hash in Rack/Rails, an Array in PHP). #parse handles either shape and
# returns a typed event per record.
SmsRu::Webhook.parse(params["data"]).each do |event|
  case event
  when SmsRu::Events::SmsStatus        # delivery report
    # event.id, event.status_code, event.created_at; event.delivered? => 103
    update_delivery_status(event.id, event.status_code)
  when SmsRu::Events::CallcheckStatus  # call-authorization result
    confirm_authorization(event.id) if event.confirmed? # or event.expired?
  # SmsRu::Events::Test (heartbeat) and ::Unknown (future types) fall through
  end
end

# Respond with exactly "100", or SMS.ru retries every 60s for up to 5 days.
```

## Error handling

Every error inherits from `SmsRu::Error`:

```ruby
SmsRu::Error                  # base class
├─ SmsRu::ConnectionError     # network/timeout/invalid response (after retries)
└─ SmsRu::ResponseError       # API returned a non-OK status; has #code and #text
   ├─ SmsRu::AuthError        # invalid api_id/token/account (codes 200, 300, 301, 302)
   └─ SmsRu::InsufficientFundsError # not enough money (code 201)
```

```ruby
begin
  client.deliver("79991234567", "Hi")
rescue SmsRu::AuthError => e
  warn "Check your api_id: #{e.text}"
rescue SmsRu::InsufficientFundsError
  warn "Top up your balance"
rescue SmsRu::ResponseError => e
  warn "SMS.ru error #{e.code}: #{e.text}"
rescue SmsRu::ConnectionError => e
  warn "Could not reach SMS.ru: #{e.message}"
end
```

Note that per-recipient failures in a bulk `deliver` are **not** raised — they are
reported on each `SmsRu::Sms` in `result.messages` (see above).

## Development

```sh
bin/setup          # install dependencies
bundle exec rake   # run RuboCop + the test suite
bin/console        # an IRB session with the gem loaded
```

## Recording test cassettes

End-to-end tests replay real SMS.ru responses recorded with [VCR](https://github.com/vcr/vcr).
The cassettes are not committed with secrets — your `api_id` is filtered out. To
record them once against your own account (message sends use `test=1`, so they are
free):

```sh
SMSRU_API_ID=your_real_api_id bundle exec rake vcr:record
```

This writes `test/cassettes/*.yml`. Commit them, then `COVERAGE=true bundle exec rake`
runs fully offline at 100% coverage. Before cassettes are recorded, the end-to-end
tests are skipped (the unit and transport tests still run).

## License

Released under the [MIT License](LICENSE.txt).
