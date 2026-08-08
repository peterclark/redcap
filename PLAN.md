# Improvement Plan

A review of the `redcap` gem at `4c1e46f`, with a phased plan to modernize the toolchain, fix confirmed
defects, build a real test suite, and refactor the two structural problems that limit what the gem can do.

Every defect listed under "Confirmed defects" was reproduced against the current code on Ruby 3.3.6, not
inferred by reading. Reproduction notes are included so each one can be turned directly into a regression
test.

---

> ## Status
>
> **Phases 1–4 are implemented and released as `0.4.0`** — see `CHANGELOG.md`. The suite went from 24 to 115
> examples; 56 of those fail against `4c1e46f` and all pass now, including a named regression test for each
> defect below.
>
> **Refactoring proposals R1–R5 are open.** They change public behavior and are still deliberately separate.
>
> Two corrections to this document, made while implementing it:
>
> - The `bindir = "exe"` bullet under C12 was **wrong**. `bin/` for development scripts and `exe/` for shipped
>   executables is the standard Bundler gem layout, and this gem ships no executables, so an empty
>   `executables` list is the correct state. Pointing `bindir` at `bin/` would have installed `console` and
>   `setup` onto users' PATH. Left as-is.
> - The error model (R3) was pulled forward into Phase 4, because item 23 required error behavior to be
>   defined before it could be tested. Timeouts came with it. Since that plus C10 makes the release
>   behavior-breaking, it shipped as `0.4.0` rather than the `0.3.2` the table below anticipated.
>
> Also deviating from Phase 3 item 12: field names are validated against an identifier pattern rather than
> against `Client#fields`, which would have cost a metadata round-trip on every query.

---

## 1. Current state

**Size.** 313 lines of library code across 4 files, 124 lines of tests across 4 files. Last substantive
commit adds `delete`/`delete_all`. Version `0.3.0`.

**What works.** The payload builder, the configuration object, the `Record`/`Client` split, and the query DSL
(`where`/`gt`/`lt`/`gte`/`lte`) are a sound shape for a REDCap wrapper. The indexed-key wire format is
correct and is the fiddliest part of the API.

**The headline problem.** The suite is green — 24 runs, 28 assertions, 0 failures — and that green is
misleading. No test performs or stubs an HTTP request, so every method that talks to REDCap (`records`,
`update`, `create`, `delete`, `find`, `save`, `destroy`, `pluck`, `all`) is entirely uncovered. Several
config assertions compare against `ENV['REDCAP_*']` and pass vacuously as `nil == nil` when no `.env` is
present. Four of the bugs below sit in that uncovered region; one of them silently discards the credentials
the README tells users to set.

**The toolchain is unusable as shipped.** `bundle install` fails outright on modern Bundler.

---

## 2. Confirmed defects

Ordered by severity. Each was reproduced; "Repro" describes how.

### C1 — `Redcap.new` silently discards block configuration (`lib/redcap.rb:17-24`)

The block form documented in the README does not work. `Redcap.new` with no arguments overwrites the global
configuration with `ENV` values — which are `nil` when unset — destroying whatever the block just set.

```ruby
Redcap.configure { |c| c.host = 'http://example.com'; c.token = 'SECRET' }
Redcap.configuration.host   # => "http://example.com"
client = Redcap.new
client.configuration.host   # => nil    ← credentials gone
```

The cause is that `new` unconditionally calls `self.configure = options`, constructing a fresh
`Configuration` from ENV, instead of preserving configuration that already exists. The existing test passes
only because it inspects `Redcap.configuration` without calling `Redcap.new` afterward.

**Fix:** only populate from ENV when no configuration has been established; merge rather than replace.

### C2 — Query values are interpolated into `filterLogic` unescaped (`lib/redcap/record.rb:124`, `:127`)

A value containing a single quote breaks out of the filter expression:

```ruby
Redcap::Record.where(name: "x' or '1'='1")
# filterLogic => "[name] = 'x' or '1'='1'"
```

Any caller passing user-supplied strings to `where` can alter the server-side filter and widen the result set
beyond what was intended. Numeric comparisons (`gt`/`lt`/`gte`/`lte`) are protected by the existing
`Integer`/`Float` type check; `where` has no such guard.

**Fix:** escape quotes and backslashes in the value, validate the field name against `Client#fields`, and add
regression tests for quote/backslash payloads.

### C3 — API token is written to logs (`lib/redcap.rb:153`)

`log "Redcap POST to #{configuration.host} with #{payload}"` interpolates the entire payload, and the token
is a payload key on every single request. Turning on the documented `client.log = true` writes the
credential to STDOUT on every call.

```
Redcap POST to http://example.com with {:token=>"SUPERSECRET", :format=>:json, :content=>:project}
```

**Fix:** redact `:token` before logging.

### C4 — `update` reports failure for any multi-record write (`lib/redcap.rb:109`)

`update` accepts an array of records but hard-codes `result['count'] == 1`. Updating two records succeeds
server-side and returns `false`:

```ruby
client.update([r1, r2])   # server reports count=2  => false
client.update([r1])       # server reports count=1  => true
```

**Fix:** return `result['count'] == data.size`, or return the count itself and let callers decide.

### C5 — `Record.find` returns an empty record instead of nil when nothing matches (`lib/redcap/record.rb:15-19`)

`self.new response.first` on an empty response builds `Record.new(nil)`, which `Hashie::Mash` turns into an
empty Mash. Callers get a truthy object with no fields rather than `nil`, so the idiomatic
`if (p = Person.find(id))` guard never fires.

**Fix:** return `nil` when the response is empty.

### C6 — `flush_cache` does not exist unless caching was on at require time (`lib/redcap.rb:160`)

`memoize(:post) if ENV['REDCAP_CACHE']=='ON'` is evaluated when the file is loaded. `flush_cache` is a
Memoist artifact, so with caching off the method the README documents raises:

```ruby
People.client.flush_cache
# => NoMethodError: undefined method `flush_cache' for an instance of Redcap::Client
```

**Fix:** always define `flush_cache` as a no-op when caching is disabled (and see R2 for the underlying
design fix).

### C7 — String field names produce a duplicated `record_id` in the payload (`lib/redcap.rb:92`)

`fields |= [:record_id]` compares a symbol against the caller's strings, so `'record_id'` and `:record_id`
both survive the union:

```ruby
records(fields: %w(record_id name))
# => "fields[0]"=>"record_id", "fields[1]"=>"name", "fields[2]"=>:record_id
```

This is the path `max_id` takes on every create. Harmless today, but it means the gem sends a malformed field
list whenever string names are used — which the README's own examples do.

**Fix:** normalize field names to strings (or symbols) once, before the union.

### C8 — `Redcap.configure` with no block raises `LocalJumpError` (`lib/redcap.rb:38-41`)

`configure` unconditionally yields. Calling it as a reader — a natural mistake given the sibling `configure=`
writer — raises `LocalJumpError: no block given (yield)` rather than returning the configuration.

**Fix:** `return configuration unless block_given?`.

### C9 — `private` is a no-op on the class methods below it (`lib/redcap/record.rb:109`)

`private` does not affect `def self.` methods. `Record.client` and `Record.comparison` are public despite the
apparent intent:

```ruby
Redcap::Record.respond_to?(:client)      # => true
Redcap::Record.respond_to?(:comparison)  # => true
```

The README depends on `client` being public (`People.client.log = true`), so the resolution is to make the
intent explicit, not to actually hide it: keep `client` public, and move `comparison` behind
`private_class_method`.

### C10 — Unimplemented query methods fail silently (`lib/redcap/record.rb:44-57`)

`find_or_create_by`, `having`, `group`, `order`, and `where_not` have empty bodies and return `nil`. A caller
writing `People.order(:age)` gets `nil` back with no indication the method does nothing.

**Fix:** raise `NotImplementedError` until implemented.

### C11 — Toolchain pins prevent installation (`redcap.gemspec:36`, `:39`, `:40`)

`bundle install` cannot resolve on any Bundler ≥ 2:

```
Because the current Bundler version (4.0.9) does not satisfy bundler ~> 1.13
  and Gemfile depends on bundler ~> 1.13, version solving has failed.
```

`rake "~> 10.0"` and `hashie "~> 3.4.6"` are similarly stale — the code runs fine against Hashie 5.1.0.

**Fix:** drop the `bundler` development dependency entirely (modern convention), relax `rake` to `>= 13`,
widen `hashie` to `>= 3.4, < 6`, and add `spec.required_ruby_version`.

### C12 — Packaging and CI metadata are broken

- `redcap.gemspec:20` — `allowed_push_host` is still the scaffold's literal `"TODO: Set to
  'http://mygemserver.com'"`, which blocks `rake release`.
- `redcap.gemspec:29` — `spec.bindir = "exe"`, but the scripts live in `bin/` and no `exe/` exists.
- `.travis.yml` targets Ruby 2.2.1 on a service that no longer runs these builds; the README's build badge
  reflects nothing.
- `LICENSE` and `LICENSE.txt` are duplicate MIT texts differing only in wrapping.
- `lib/redcap.rb:14` — a module-level `attr_reader :configuration` that defines an unreachable instance
  method. Dead code.

---

## 3. Phased plan

Phases are ordered so that each one is verifiable when it lands. Phase 1 exists because without it the
correctness work in Phase 3 cannot be checked by anyone who clones the repo.

### Phase 1 — Make the project installable and testable

*Fixes C11, C12. No library behavior changes.*

1. Remove the `bundler` development dependency; relax `rake` to `>= 13`; widen `hashie` to `>= 3.4, < 6`.
2. Set `spec.required_ruby_version = ">= 3.0"`; fix `bindir` to `"bin"`; remove the `allowed_push_host` TODO.
3. Add `minitest`, `webmock`, and `rake` as development dependencies.
4. Replace `.travis.yml` with a GitHub Actions workflow running the suite on Ruby 3.1/3.2/3.3.
5. Delete `LICENSE.txt`; update the README badges to point at Actions.

**Done when** a fresh clone runs `bundle install && rake test` successfully on supported Rubies.

### Phase 2 — Build the test harness

*No behavior changes; establishes the safety net Phase 3 needs.*

6. Add WebMock, pinned to `disable_net_connect!`, so an unstubbed request fails loudly rather than escaping
   to the network.
7. Add a `test/support/` helper that stubs the REDCap endpoint and captures request bodies, so tests can
   assert on what was sent as well as what was returned. Parse the form body back into a hash for assertions.
8. Reset global state (`Redcap.configure = nil`, `Record`'s memoized client) in `setup`/`teardown` so
   randomized ordering is safe.
9. Fix the vacuous ENV assertions in `test/test_redcap.rb` to set explicit values rather than comparing
   `nil` to `nil`, and replace the `assert_equal nil` calls that Minitest 6 will reject with `assert_nil`.

**Done when** the existing 24 tests still pass, ordering is order-independent, and an accidental real HTTP
request fails the suite.

### Phase 3 — Fix the confirmed defects

Each item lands with the regression test that proves it, written first against the reproduction above.

10. **C1** — configuration precedence. Also settle the intended semantics explicitly: explicit options >
    prior `configure` block > ENV. This is the only fix that changes documented behavior, so it is worth
    calling out in the changelog as a fix rather than a break.
11. **C3** — redact the token in log output.
12. **C2** — escape filter values; validate field names.
13. **C4** — `update` count comparison against `data.size`.
14. **C5** — `find` returns nil on empty.
15. **C7** — normalize field-name types.
16. **C6** — `flush_cache` always defined.
17. **C8** — `configure` without a block returns the configuration.
18. **C9** — `private_class_method :comparison`; document `client` as public.
19. **C10** — `NotImplementedError` for the five stubs.
20. **C12** — remove the dead `attr_reader`.

**Done when** each defect has a test that fails on `4c1e46f` and passes after the fix.

### Phase 4 — Coverage for the untested surface

21. `Client`: `records` (all four argument combinations), `metadata`, `fields`, `project`, `max_id`,
    `create`, `update`, `delete` — asserting both the request body and the parsed return value.
22. `Record`: `find`, `all`, `ids`, `count`, `pluck`, `select`, `where`, `gt`/`lt`/`gte`/`lte`, `save`
    (both the update and create branches), `destroy`, `delete_all`.
23. Error paths: non-2xx responses, REDCap's error-shaped JSON, malformed/non-JSON bodies, and a nil `host`.
    These currently have no defined behavior at all — decide it here (see R3) and encode it.
24. Guard-clause behavior: `find` with non-Integer input, `delete` with a non-array or empty array, `pluck`
    with nil, `comparison` with a non-Hash or multi-key Hash.

**Target:** every public method on both classes exercised, with request-body assertions rather than
return-value assertions alone.

---

## 4. Proposed refactoring

These are design changes, not bug fixes. They are deliberately separated from Phases 1–4 because they alter
public behavior and warrant a `0.4.0` and a migration note. Recommended order: R1 → R3 → R2 → R4.

### R1 — Per-client configuration; retire the global singleton *(highest value)*

**Problem.** Configuration lives in a module-level ivar (`lib/redcap.rb:26-36`) and `Record` memoizes a
single client in a class variable (`lib/redcap/record.rb:5`, `:111-114`). Class variables are shared with all
subclasses, so `class People < Redcap::Record` and `class Trials < Redcap::Record` share one client and one
token. **The gem cannot talk to two REDCap projects in one process** — directly contradicting the README's
"name the class after your REDCap project" guidance. It is also the root cause of C1 and of the test-ordering
fragility in Phase 2.

**Proposal.** Move configuration into the `Client` instance. Let `Record` subclasses declare their own:

```ruby
class People < Redcap::Record
  redcap host: ENV['REDCAP_HOST'], token: ENV['PEOPLE_TOKEN']
end
```

Store the client in a *class-level instance variable* (`@client`, not `@@client`) with inheritance-aware
lookup, so each subclass gets its own and unconfigured subclasses fall back to a process default. Keep
`Redcap.configure` and the zero-argument `Redcap.new` working against that default for backward
compatibility.

**Impact:** fixes the one-project-per-process ceiling, makes tests isolable, and removes the class of bug C1
belongs to.

### R2 — Make caching an injectable, runtime concern

**Problem.** `memoize(:post) if ENV['REDCAP_CACHE']=='ON'` (`lib/redcap.rb:160`) is evaluated at load time,
so the mode is fixed before any application code runs, cannot be changed or tested in-process, and determines
whether `flush_cache` exists at all (C6). Because the memoized method is `post` itself, writes are cached too
— `update`/`create`/`delete` each call `flush_cache` first purely to work around that.

**Proposal.** Introduce a small cache collaborator with `fetch`/`clear`, defaulting to a null object, and
select it from configuration at initialization rather than from ENV at load. Cache only read operations, so
the write-then-flush dance disappears. Keep `REDCAP_CACHE=ON` as a recognized default so existing `.env`
files keep working.

### R3 — A real error model

**Problem.** `post` (`lib/redcap.rb:152-158`) has no error handling. `RestClient` raises its own exception
hierarchy on non-2xx, `JSON.parse` raises on REDCap's non-JSON error bodies, and callers see raw
`RestClient::` and `JSON::` exceptions leaking through the abstraction. There is no timeout either, so a
hung server hangs the caller indefinitely.

**Proposal.** Add a `Redcap::Error` base with `ConfigurationError` (nil host/token), `ResponseError`
(non-2xx, carrying status and body), and `ParseError`. Detect REDCap's `{"error": "..."}` response shape
explicitly. Add configurable open/read timeouts with sane defaults. This is a prerequisite for meaningful
tests in Phase 4 item 23.

### R4 — Extract the query builder; then chaining becomes cheap

**Problem.** `Record.comparison` (`lib/redcap/record.rb:116-132`) mixes three concerns: argument validation,
filter-string construction, and result instantiation. Its `elsif` chain re-tests the operator that the caller
already chose, and line 127 assigns to a local `response` that is immediately discarded by the surrounding
assignment.

**Proposal.** Extract a `Redcap::Query` value object holding fields, filter clauses, and record ids, with a
`to_payload`. `where`/`gt`/`lt`/… become thin constructors over it. This isolates escaping (C2) in one place
and makes README TODO #1 — `People.where(age: 40).select(:first_name)` — a natural follow-on: return a
`Query` that is `Enumerable` and executes lazily. It also creates the seam for `order`, `group`, and
`where_not` (C10).

### R5 — Reconsider `Hashie::Mash` as the record base

**Problem.** Inheriting from `Mash` means REDCap field names share a namespace with the record's own methods.
A project with a field named `id`, `save`, `count`, `client`, or `metadata` collides with real behavior, and
`Mash` emits override warnings when it happens. It is also why C5 is possible: `Mash.new(nil)` is a valid
empty record, so absence and emptiness are indistinguishable.

**Proposal.** Not urgent, and a real break — record this as a known limitation in the README first, keep
`Mash` for now, and revisit if field collisions are reported in practice. If it is ever changed, the
replacement is a plain attributes hash with `method_missing` restricted to keys actually present.

---

## 5. Sequencing, risk, and versioning

| Phase | Behavior change | Suggested release |
|---|---|---|
| 1 — toolchain | none | `0.3.1` |
| 2 — test harness | none | — |
| 3 — defect fixes | C1 and C4 change observable results; both are fixes to behavior no caller could have relied on deliberately | `0.3.2` |
| 4 — coverage | none | — |
| R1–R4 — refactors | yes, with compatibility shims | `0.4.0` |
| R5 | breaking | deferred |

**Risks.**

- **No integration testing against a real REDCap instance.** Everything in Phases 2–4 is stubbed, which
  verifies what the gem *sends* but not that REDCap accepts it. Reproductions C4 and C7 in particular encode
  an assumption about REDCap's response shape taken from the existing code. Confirming these against a live
  or demo instance before shipping Phase 3 would be worthwhile; failing that, the risk should be stated in
  the changelog.
- **C1 is a behavior change that could surprise anyone who worked around it** by relying on `Redcap.new`
  resetting to ENV. Worth an explicit changelog entry rather than a silent fix.
- **R1 touches every entry point.** It should land alone, after Phases 1–4 give it a net to land into.
