# smsru_ruby

[![Gem Version](https://badge.fury.io/rb/smsru_ruby.svg)](https://rubygems.org/gems/smsru_ruby)
[![CI](https://github.com/svyatov/smsru_ruby/actions/workflows/main.yml/badge.svg)](https://github.com/svyatov/smsru_ruby/actions/workflows/main.yml)
[![codecov](https://codecov.io/gh/svyatov/smsru_ruby/branch/main/graph/badge.svg)](https://codecov.io/gh/svyatov/smsru_ruby)
[![Documentation](https://img.shields.io/badge/docs-rubydoc.info-blue.svg)](https://rubydoc.info/gems/smsru_ruby)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-CC342D.svg)](https://www.ruby-lang.org)
[![Types: RBS](https://img.shields.io/badge/types-RBS-8A2BE2.svg)](https://github.com/svyatov/smsru_ruby/tree/main/sig)

A modern, **dependency-free**, **fully typed** Ruby client for the [SMS.ru](https://sms.ru) HTTP API —
typed results, typed errors, shipped RBS signatures, and first-class webhooks.

It is a clean, idiomatic Ruby port of the official [SMS.ru PHP library](https://sms.ru/php):
send single or bulk SMS, schedule delivery, check cost and delivery status, verify
users by phone call, inspect your balance/limits/senders, manage the stoplist, and
register delivery callbacks — all returning typed, immutable result objects and
raising typed errors.

## Why smsru_ruby?

- **Zero runtime dependencies** — only Ruby's standard library (`net/http`, `json`, `openssl`).
- **Fully typed** — immutable `Data` result objects, not raw hashes, plus a typed error hierarchy: `rescue SmsRu::Error` catches everything.
- **RBS signatures shipped** (`sig/`) and Steep-checked — type-check your integration out of the box.
- **First-class webhooks** — parse signed delivery and call-authorization callbacks into typed events; the signature is verified in **constant time** (timing-attack safe).
- **Secret-safe by default** — TLS verified; the optional logger never logs your `api_id`, phone numbers, or message text. Configurable timeout and transport retries.
- **Outcome vs. delivery state** — two distinct ideas, each with its own predicates (`ok?` vs. `delivered?`/`pending?`/`failed?`), never conflated.
- **100% test & documentation coverage, enforced in CI** across Ruby 3.2–4.0.

## What's covered

The full SMS.ru API, mapped to an idiomatic Ruby surface:

| Capability | Method |
| --- | --- |
| Send — single, bulk, or per-number text | `client.deliver` |
| Price a message before sending | `client.cost` |
| Delivery status, with state predicates | `client.status` |
| Verify by flash call (outbound) | `client.call` |
| Verify by callcheck (inbound) | `client.callcheck` |
| Balance, limits, free limit, senders | `client.my` |
| Validate credentials | `client.auth.ok?` |
| Stoplist — add, remove, list | `client.stoplist` |
| Webhook URLs — add, remove, list | `client.callbacks` |
| Parse & verify incoming webhooks | `SmsRu::Webhook` |

## Table of contents

- [Why smsru_ruby?](#why-smsru_ruby)
- [What's covered](#whats-covered)
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
  timeout: 30,        # open/read timeout in seconds (default: 30)
  test: false,        # when true, every `deliver` defaults to test mode (no charge)
  retries: 5,         # retries on transport failure; 0 disables (default: 5, matching the PHP lib)
  from: "MyCompany",  # default sender name for `deliver` (override per call)
  logger: Logger.new($stdout) # optional; logs the request path + transport failures
)
```

Retries apply only to transport-level problems (timeouts, refused connections).
API errors are never retried — they are raised immediately.

`from` is a per-client default so you don't repeat your sender name on every call;
a per-call `from:` always wins. The `logger` logs only the request path and
transport failures — never your `api_id`, phone numbers, or message text.

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
result.balance                 # => 4122.56
result.messages.each do |sms|
  if sms.ok?
    puts "#{sms.phone}: sent as #{sms.sms_id}"
  else
    puts "#{sms.phone}: rejected (#{sms.error_code}) #{sms.error_text}"
  end
end

# Or use the collection helpers:
result.ok?                     # => true only if every recipient was accepted
result.ok                      # => [SmsRu::Sms, ...] accepted recipients
result.failed                  # => [SmsRu::Sms, ...] rejected recipients
```

## Cost and status

```ruby
# Price a message before sending (text is optional; omit it for the price of 1 SMS)
cost = client.cost("79991234567", "How much?")
cost.total_cost  # => 1.74
cost.total_sms   # => 2

# Same collection helpers as a send result:
cost.ok?                       # => true only if every recipient was priced
cost.failed                    # => [SmsRu::CostItem, ...] recipients that errored
cost.failed.first.error_code   # => 207

# Delivery status — one id or an Array of ids
status = client.status("000000-10000000")
status.status_code  # => 103   (the delivery state code)
status.status_text  # => "Сообщение доставлено"

# State predicates instead of memorizing codes:
status.delivered?   # => true  (code 103)
status.pending?     # => false (codes 100–102, still in transit)
status.failed?      # => false (codes 104–108, 150)
status.found?       # => true  (false only when the id is unknown, code -1)

statuses = client.status(["000000-10000000", "000000-10000001"]) # => [SmsRu::Status, ...]
```

Every code has a named constant under `SmsRu::Statuses` (e.g.
`SmsRu::Statuses::DELIVERED == 103`, `::EXPIRED`, `::READ`) for the cases the
predicates don't cover. The same predicates are available on
`SmsRu::Events::SmsStatus` from webhook payloads.

> **Outcome vs. delivery state — two ideas, two names.** `ok?` (with
> `error_code`/`error_text` on a rejected `Sms`/`CostItem`) answers *did the
> request succeed for this recipient*. `status_code` (with
> `delivered?`/`pending?`/`failed?`) answers *where the message is in delivery* —
> and only `Status` and webhook events carry it.

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
# In Rails, params[:data] is ActionController::Parameters, not a Hash — convert
# it with .to_unsafe_h first, or the numeric-key ordering the signature depends
# on is skipped and the check below rejects the payload. The payload is
# signature-verified, so to_unsafe_h is safe here (.to_h would drop keys).
# In bare Rack params["data"] is already a Hash; pass it as-is.
data = params[:data].to_unsafe_h

# Reject forged callbacks: SMS.ru signs every payload with your api_id.
# The check is constant-time (timing-attack safe).
unless SmsRu::Webhook.valid?(data, params[:hash], "YOUR_API_ID")
  return head(:forbidden)
end

# SMS.ru sends up to 100 records as POST fields data[0]..data[N]
# (a Hash in Rack, an Array in PHP). #parse handles either shape and
# returns a typed event per record.
SmsRu::Webhook.parse(data).each do |event|
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
bin/setup            # install dependencies
bundle exec rake     # run RuboCop, validate RBS signatures, and the test suite
bundle exec rake steep        # type-check lib/ against sig/ (Steep, strict diagnostics)
bundle exec rake steep:stats  # report type coverage (typed % per file)
bundle exec rake rbs:test     # run the suite verifying real values against the signatures
bin/console          # an IRB session with the gem loaded
```

The signatures are held to their own standard: Steep runs under its **strict**
diagnostics (no implicit `untyped`, no unannotated collections) at **100% type
coverage**, gated in CI. Loosely-typed JSON from SMS.ru (which returns, say,
`total_limit` as the string `"10"`) is normalized into the declared types at the
parse boundary, and `rbs:test` checks that the values flowing through the suite
actually match `sig/` at runtime — so the types can't drift from the code.

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
