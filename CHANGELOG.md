# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Versioning tracks the official SMS.ru PHP library.

## [Unreleased]

## [1.2.0] - 2026-06-25

### Added

- Initial release: a modern, dependency-free Ruby port of the official SMS.ru PHP library.
- `SmsRu#deliver` — send to one number, many numbers (same text), or a Hash of
  `number => text` pairs; with `from`, `time`, `ttl`, `daytime`, `translit`,
  `test`, `ip`, and `partner_id` options.
- `SmsRu#cost`, `#status`, `#call` (call-password).
- Account info: `#balance`, `#limit`, `#free`, `#senders`, `#authed?`.
- Stoplist management via `SmsRu#stoplist` (`#add`, `#remove`, `#list`).
- Callback (webhook) management via `SmsRu#callbacks` (`#add`, `#remove`, `#list`)
  and inbound payload parsing with `SmsRu::Callback.parse`.
- Typed, immutable result objects and a typed error hierarchy under `SmsRu::Error`.
- Configurable `timeout`, global `test` mode, and `retries` (TLS always verified).

[Unreleased]: https://github.com/svyatov/sms_ru_ruby/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/svyatov/sms_ru_ruby/releases/tag/v1.2.0
