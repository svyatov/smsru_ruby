# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-26

First public release. A Ruby port of the official SMS.ru PHP library covering the
same API, reworked to be idiomatic Ruby. How it differs from the original:

- **Idiomatic, namespaced API** instead of flat `get_*`/`add_*` methods: account
  reads under `client.my` (`#balance`, `#limit`, `#free_limit`, `#senders`),
  credential check via `client.auth.ok?`, plus `client.stoplist`,
  `client.callbacks`, and `client.callcheck` sub-resources. Keyword arguments for
  every optional send parameter, plus a per-client `from` default.
- **Typed, immutable `Data` results** that separate *operation outcome* from
  *delivery state*: `#ok?` plus `#error_code`/`#error_text` on rejected
  `Sms`/`CostItem` entries; `#delivered?`/`#pending?`/`#failed?`/`#found?` and
  named `SmsRu::Statuses` constants for the delivery `status_code` on `Status`
  and webhook events; `#ok?`/`#ok`/`#failed` collection helpers on `SendResult`
  and `Cost`; plus `#confirmed?` and `#available_today`. No raw decoded JSON or
  magic numbers.
- **Typed error hierarchy** under `SmsRu::Error` (`AuthError`,
  `InsufficientFundsError`, `ResponseError`, `ConnectionError`) — errors are
  raised, not returned as status codes you have to inspect.
- **First-class inbound webhooks**: `SmsRu::Webhook.parse` decodes the callback
  POST into typed events (`SmsRu::Events::SmsStatus`, `CallcheckStatus`, `Test`,
  `Unknown`), and `SmsRu::Webhook.valid?` verifies the signature.
- **Zero runtime dependencies** (Ruby stdlib only, no curl), TLS verified by
  default, with configurable `timeout`, `retries`, global `test` mode, and an
  optional `logger`.
- **Ships RBS type signatures** (`sig/`) checked at 100% coverage under Steep's
  strict profile and verified against the test suite at runtime (`rbs test`);
  SMS.ru's loosely-typed JSON is normalized to the declared types at the parse
  boundary, so result objects never surface raw wire values.

[Unreleased]: https://github.com/svyatov/smsru_ruby/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/svyatov/smsru_ruby/releases/tag/v1.0.0
