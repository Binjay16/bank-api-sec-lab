# bank-api-sec-lab

A small bank-style JSON API in Rails, **deliberately seeded with security flaws**, then scanned with
[Brakeman](https://brakemanscanner.org/), documented, fixed, and covered by regression tests.

> ⚠️ **Never deploy the `v0-vulnerable` tag.** It exists to be attacked and fixed in a lab.
> Every credential in `db/seeds.rb` is a throwaway demo value.

## Result at a glance

| | `v0-vulnerable` | `v1-fixed` |
|---|---|---|
| Brakeman warnings (`--run-all-checks`) | 17 | 0 |
| Regression tests passing | 1 / 17 | 17 / 17 |
| Flaws found by *human review only* | 10 | 0 remaining |

The interesting part is the second row of findings: Brakeman caught the injection bugs but missed
the ones that would hurt a bank most (broken object-level authorization, negative-amount and race-condition
money bugs, unsafe deserialization). Full write-up: **[docs/FINDINGS.md](docs/FINDINGS.md)**.

## The app

| Endpoint | Purpose |
|---|---|
| `POST /users`, `POST /login`, `GET /logout` | Signup, token login, logout redirect |
| `GET /users`, `GET /users/:id` | Admin list / profile |
| `GET /accounts`, `GET /accounts/:id`, `GET /accounts/lookup` | Accounts, payee lookup |
| `GET/POST /transfers` | Transfer history and search, send money |
| `GET /accounts/:id/statement/export`, `GET /statements/download` | CSV statement (gzip) |
| `PUT /preferences`, `GET /reports/:type` | User preferences, reports |

Auth is `Authorization: Bearer <api_token>`. Money is stored as integer cents.

## Git history is the lesson

```
v0-vulnerable   Add deliberately vulnerable bank API
                Add Brakeman baseline report (17 warnings)
                Fix injection-class flaws
                Fix authn/authz
                Fix transfer integrity
                Harden config, move to supported Rails/Ruby
v1-fixed        Add tests, CI, reports, docs
```

Read it with `git log -p`, or diff the two ends: `git diff v0-vulnerable v1-fixed -- app`.

## Run it

```bash
bundle install                  # also creates Gemfile.lock; commit it
bin/rails db:setup              # schema + demo seeds
bin/rails server

bin/rails test                  # 17 security regression tests
bundle exec brakeman --run-all-checks --no-pager
```

Reproduce the "before" scan:

```bash
git checkout v0-vulnerable
bundle exec brakeman --run-all-checks --no-pager
```

Ruby >= 3.4 and Rails 8.1 are targeted. The test suite was developed against Rails 6.1 shims; see
"Known limits" in [docs/FINDINGS.md](docs/FINDINGS.md#d-known-limits-of-this-exercise-read-before-quoting-numbers).

## Layout

```
app/controllers/     one controller per resource (where most flaws live)
app/models/          User, Account, Transfer
app/services/reports Report classes (the reflection flaw loads these)
docs/FINDINGS.md     findings, fixes, and what Brakeman missed
docs/reports/        raw Brakeman output, before and after
test/integration/    regression tests, one per flaw
.github/workflows/   CI: Brakeman (fail on warn) + tests
```

## License

MIT. Educational use only.
