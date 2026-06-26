# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig"
  check "lib"

  # Strict: every implicit `untyped` (FallbackAny) and unannotated empty
  # collection is surfaced, so coverage gaps cannot hide.
  configure_code_diagnostics(D::Ruby.strict)

  library "logger", "openssl", "json", "net-http", "uri"
end
