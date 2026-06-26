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
  every optional send parameter.
- **Typed, immutable `Data` results** with predicate and DX helpers (`#ok?`,
  `#delivered?`, `#confirmed?`, `#available_today`) instead of raw decoded JSON.
- **Typed error hierarchy** under `SmsRu::Error` (`AuthError`,
  `InsufficientFundsError`, `ResponseError`, `ConnectionError`) — errors are
  raised, not returned as status codes you have to inspect.
- **First-class inbound webhooks**: `SmsRu::Webhook.parse` decodes the callback
  POST into typed events (`SmsRu::Events::SmsStatus`, `CallcheckStatus`, `Test`,
  `Unknown`), and `SmsRu::Webhook.valid?` verifies the signature.
- **Zero runtime dependencies** (Ruby stdlib only, no curl), TLS verified by
  default, with configurable `timeout`, `retries`, and global `test` mode.

[Unreleased]: https://github.com/svyatov/smsru_ruby/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/svyatov/smsru_ruby/releases/tag/v1.0.0
