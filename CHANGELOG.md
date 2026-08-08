# Changelog

## 0.4.0

Implements Phases 1–4 of [PLAN.md](PLAN.md). The refactoring proposals R1–R5 in that document are **not**
included and remain open.

### Fixed

- **`Redcap.new` no longer discards block configuration.** A bare `Redcap.new` after `Redcap.configure { … }`
  used to rebuild the configuration from `ENV`, silently replacing the credentials the block had just set
  with `nil`. Precedence is now: explicit options > configuration already established > environment. **If you
  relied on `Redcap.new` resetting configuration to the environment, call `Redcap.configure = nil` first.**
- **Query values are escaped before being interpolated into `filterLogic`.** A value containing a single
  quote — `where(name: "O'Brien")`, or anything caller-supplied — used to close the string literal early, so
  the remainder was parsed as filter syntax and could widen the result set. Field names are now also
  validated as identifiers.
- **The API token is redacted from log output.** With `client.log = true`, the token was interpolated into
  every request's log line.
- **`update` no longer reports failure for multi-record writes.** The returned count was compared against a
  hard-coded `1`, so a successful write of two records returned `false`. It is now compared against the
  number of records sent.
- **`Record.find` returns `nil` when nothing matches** instead of a truthy empty record, so the usual
  `if (person = Person.find(id))` guard works.
- **`flush_cache` is always defined.** It was a Memoist artifact that existed only when `REDCAP_CACHE` was set
  at require time, so the call the README documents raised `NoMethodError` whenever caching was off. It is now
  a no-op in that case.
- **Field lists no longer carry a duplicate `record_id`.** Passing string field names left both `'record_id'`
  and `:record_id` in the payload; names are normalized before the union.
- **`Redcap.configure` without a block returns the configuration** instead of raising `LocalJumpError`.

### Changed

- **Errors are now `Redcap::Error` descendants.** `Redcap::ConfigurationError` (missing host or token, raised
  before any request), `Redcap::ResponseError` (non-2xx, transport failure, or REDCap's `{"error": …}` body;
  carries `status` and `body`), and `Redcap::ParseError` (2xx that is not JSON). Previously `RestClient::` and
  `JSON::` exceptions leaked through unchanged.
- **Requests now time out.** `timeout` and `open_timeout` are configurable and default to 60 seconds; a hung
  server previously hung the caller indefinitely.
- **`find_or_create_by`, `having`, `group`, `order`, and `where_not` raise `NotImplementedError`** instead of
  returning `nil` silently.
- Query argument validation raises `ArgumentError` rather than a bare `RuntimeError`.
- `Record.comparison` is genuinely private now (`private_class_method`); the `private` keyword never applied
  to it. `Record.client` stays public, as the README documents.
- Added `Record.reset_client!` to drop the memoized client after reconfiguring.

### Development

- Removed the `bundler ~> 1.13` development pin, which made `bundle install` fail on every Bundler ≥ 2.
  Relaxed `rake` to `>= 13`, widened `hashie` to `>= 3.4, < 6`, and set `required_ruby_version >= 3.0`.
- Replaced the dead Travis config with GitHub Actions running the suite on Ruby 3.1, 3.2, and 3.3.
- Added a WebMock-based test harness. Net connections are disabled in tests, so an unstubbed request fails
  loudly. Test coverage went from 24 to 115 examples, and now covers every method that talks to REDCap —
  previously none did.
- Removed a duplicate `LICENSE.txt` and a dead module-level `attr_reader :configuration`.

### Known limitations

- Nothing here is verified against a live REDCap instance; the suite asserts what the gem *sends*. In
  particular, backslash-escaping of quotes in `filterLogic` follows the common convention but is not confirmed
  against REDCap's parser.
- One REDCap project per process still. `Record`'s client is a class variable shared with every subclass, so
  two `Record` subclasses cannot use different tokens. This is proposal R1 in PLAN.md.
