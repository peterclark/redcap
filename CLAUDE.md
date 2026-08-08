# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Ruby gem wrapping the [REDCap](https://www.project-redcap.org/) REST API. It exposes two layers: a thin
HTTP client (`Redcap::Client`) and an ActiveRecord-flavored facade (`Redcap::Record`) that user code
subclasses, one subclass per REDCap project.

## Commands

```bash
rake test                                   # full suite (Rakefile globs test/**/test_*.rb)
ruby -Ilib -Itest test/test_record.rb       # one file
ruby -Ilib -Itest test/test_record.rb -n test_client_is_reused   # one test by name
ruby -Ilib -Itest test/test_record.rb -n "/find_rejects/"        # tests matching a pattern
bin/console                                 # IRB with the gem loaded and a sample `Person` class
```

### Toolchain caveat

`bundle install` fails on any modern Bundler: the gemspec pins
`spec.add_development_dependency "bundler", "~> 1.13"`, which no Bundler ≥ 2 can satisfy. Until that pin is
removed, install the runtime deps directly and run tests without Bundler:

```bash
gem install rest-client hashie memoist dotenv minitest --no-document
ruby -Ilib -Itest -e 'Dir.glob("./test/test_*.rb").each { |f| require f }'
```

The gemspec also pins `hashie "~> 3.4.6"`, which is far behind the Hashie the code actually runs against
(5.x) — expect friction when touching gemspec constraints.

## Architecture

**Every REDCap operation is a form POST to one URL.** There are no REST paths. `configuration.host` is the
single endpoint; the operation is selected by the `content:` key in the body (`:record`, `:metadata`,
`:project`), sometimes narrowed by `action:` (`:delete`) or `returnContent:` (`:count`, `:ids`). The API
token travels in the request body on every call.

`Client#build_payload` (private) is the one place that assembles this. Note the non-obvious wire format: array
arguments are flattened into indexed **string** keys — `records: [1,2]` becomes `"records[0]" => 1,
"records[1]" => 2` — not nested arrays. Payload-shape tests live in `test/test_payload.rb` and reach
`build_payload` via `send`.

**Configuration is process-global.** `Redcap.configuration` is a module-level ivar holding one
`Configuration`; `Client#configuration` just delegates to it. `Redcap.new` *reassigns* that global
(`self.configure = options`) rather than building per-client state, so the last `Redcap.new` call wins for
every client already constructed. `Dotenv.load` runs at require time, so `.env` is read as a side effect of
`require 'redcap'`.

**`Redcap::Record` is a `Hashie::Mash` subclass**, so a record is a hash whose REDCap fields are also
methods (`person.first_name`). Two consequences worth keeping in mind: a REDCap field colliding with a method
name (`id`, `save`, `count`) shadows or is shadowed by real behavior, and `Record.new(nil_or_empty)` yields an
empty Mash rather than nil — absence is not distinguishable from an empty record without an explicit check.

**All `Record` subclasses share one client.** `@@client` is a class variable on `Redcap::Record`, memoized on
first use via `Redcap.new`, and class variables are shared with every subclass. Combined with the global
configuration above, this means **one REDCap project (one token) per process** — defining `class People <
Redcap::Record` and `class Trials < Redcap::Record` does not give them separate tokens, despite the README
suggesting a class per project.

The `private` keyword at `lib/redcap/record.rb:109` does **not** apply to the `def self.` methods below it —
Ruby's `private` only affects instance methods. `Record.client` and `Record.comparison` are public, and the
README documents calling `People.client.log = true`, so treat `client` as public API regardless of intent.

**Query methods funnel through `Record.comparison`,** which builds REDCap `filterLogic` strings
(`"[age] > 40"`). `where`/`gt`/`lt`/`gte`/`lte` differ only by operator; `where(id: [...])` is special-cased to
fetch by record id instead of building a filter. Values are interpolated into the filter string without
escaping.

**Caching is wired at class-definition time.** `memoize(:post) if ENV['REDCAP_CACHE']=='ON'` runs when
`lib/redcap.rb` is loaded, so the env var must be set before `require`, cannot change at runtime, and
`flush_cache` (a Memoist artifact) simply does not exist on the client when caching is off. Because the
memoized method is `post` itself, writes are cached too; `update`/`create`/`delete` each call `flush_cache`
first to compensate. This makes cache behavior effectively untestable in-process.

`Record.find_or_create_by`, `having`, `group`, `order`, and `where_not` are declared but empty — they return
nil silently rather than raising `NotImplementedError`.

## Testing conventions

Minitest, no stubbing library, no HTTP mocking. Nothing that performs a request is currently covered — the
suite exercises configuration, the payload builder, and client identity only. Several assertions compare
config values against `ENV['REDCAP_*']`, so they pass vacuously (nil == nil) when no `.env` is present; keep
that in mind before treating a green suite as evidence.

Tests mutate the global `Redcap.configuration` (`test_it_accepts_a_block`), and Minitest randomizes order, so
new tests should set up their own configuration in `setup` rather than inherit it.
