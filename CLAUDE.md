# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Ruby gem wrapping the [REDCap](https://www.project-redcap.org/) REST API. It exposes two layers: a thin
HTTP client (`Redcap::Client`) and an ActiveRecord-flavored facade (`Redcap::Record`) that user code
subclasses, one subclass per REDCap project.

`PLAN.md` holds the review this codebase was worked from. Phases 1–4 are done; refactoring proposals R1–R5
are still open, and R1 in particular explains the biggest structural constraint below.

## Commands

```bash
bundle install
bundle exec rake test                       # full suite
ruby -Ilib -Itest test/test_record.rb       # one file
ruby -Ilib -Itest test/test_record.rb -n test_find_returns_a_record       # one test
ruby -Ilib -Itest test/test_record.rb -n "/escapes/"                      # by pattern
bin/console                                 # IRB with the gem loaded and a sample `Person` class
```

## Architecture

**Every REDCap operation is a form POST to one URL.** There are no REST paths. `configuration.host` is the
single endpoint; the operation is selected by the `content:` key in the body (`:record`, `:metadata`,
`:project`), sometimes narrowed by `action:` (`:delete`) or `returnContent:` (`:count`, `:ids`). The API
token travels in the request body on every call — which is why `Client#loggable` redacts it before anything
reaches the logger.

`Client#build_payload` (private) is the one place that assembles this. Note the non-obvious wire format: array
arguments are flattened into indexed **string** keys — `records: [1,2]` becomes `"records[0]" => 1,
"records[1]" => 2` — not nested arrays. `Client#records` normalizes field names to strings before adding
`record_id`, because a mixed `'record_id'`/`:record_id` union used to put the same field in twice.

**Configuration is process-global**, held in a module-level ivar on `Redcap` and read by `Client` through
`Redcap.configuration`. Precedence is explicit options > configuration already established > `ENV`. This
ordering is load-bearing: a bare `Redcap.new` must **not** rebuild the configuration, or it wipes out
whatever a preceding `Redcap.configure` block set. There is a regression test for exactly that
(`test_block_configuration_survives_a_bare_new`). `Dotenv.load` runs at require time, so `.env` is read as a
side effect of `require 'redcap'`.

**`Redcap::Record` is a `Hashie::Mash` subclass**, so a record is a hash whose REDCap fields are also
methods (`person.first_name`). A REDCap field colliding with a method name (`id`, `save`, `count`) shadows or
is shadowed by real behavior. `Mash.new(nil)` is a valid empty record, which is why `find` checks for an
empty response explicitly rather than relying on truthiness.

**All `Record` subclasses share one client.** `@@client` is a class variable on `Redcap::Record`, and class
variables are shared with every subclass. Combined with the global configuration, this means **one REDCap
project (one token) per process**, despite the README's class-per-project framing. Fixing this is R1 in
`PLAN.md`; until then, `Record.reset_client!` is the escape hatch after reconfiguring, and the test helper
calls it between tests.

**Query methods funnel through `Record.comparison`,** which builds REDCap `filterLogic` strings
(`"[age] > 40"`). `where`/`gt`/`lt`/`gte`/`lte` differ only by operator; `where(id: [...])` is special-cased to
fetch by record id instead of building a filter. Values pass through `escape` and field names through
`field_name!` — an unescaped quote closes the filter's string literal early and the rest is read as syntax.
Both are `private_class_method`; note that a bare `private` would not work here, since it does not apply to
`def self.` methods.

**Caching is wired at class-definition time.** `memoize :post if ENV['REDCAP_CACHE'] == 'ON'` runs when
`lib/redcap.rb` is loaded, so the env var must be set before `require` and cannot change at runtime. When
caching is off, a no-op `flush_cache` is defined instead — it needs an explicit `public`, since it sits below
`private` in the class body. Because the memoized method is `post` itself, writes are cached too, so
`update`/`create`/`delete` each call `flush_cache` first. Making this injectable is R2.

**Errors** all descend from `Redcap::Error` (`lib/redcap/errors.rb`): `ConfigurationError` before a request is
attempted, `ResponseError` for non-2xx / transport failure / REDCap's `{"error": …}` body, `ParseError` for a
2xx that is not JSON. Keep `RestClient::` and `JSON::` exceptions from escaping `Client#execute` and
`Client#parse`.

## Testing conventions

Minitest plus WebMock, with `WebMock.disable_net_connect!` — an unstubbed request fails rather than reaching
the network. `test/support/redcap_stub.rb` stubs the single endpoint and records every request body, decoded
from form encoding; **assert on `last_request_body` as well as the return value**, since what the gem sends is
the part REDCap actually sees. `stub_redcap_sequence` handles calls that make more than one request (`save` on
a new record fetches `max_id` first).

Configuration and `Record`'s client are process-global and Minitest randomizes order, so `Minitest::Test#setup`
in `test_helper.rb` resets both. A subclass defining `setup` must call `super`.

Use `with_env` rather than assigning `ENV` directly — several older assertions compared config against
`ENV['REDCAP_*']` and passed vacuously as `nil == nil`.

When fixing a bug, add the regression test with a comment naming the old behavior, and confirm it fails
against the previous code before considering it done.
