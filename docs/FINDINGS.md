# Findings report: `bank-api-sec-lab`

Target: the `v0-vulnerable` tag (a Rails API, 167 non-blank lines under `app/`).
Tooling: Brakeman 8.1.0, `--run-all-checks` (includes the optional `UnscopedFind` check).
Raw output: [`reports/brakeman-before.txt`](reports/brakeman-before.txt) / `.json`, and
[`reports/brakeman-after.txt`](reports/brakeman-after.txt) / `.json`.

| | v0-vulnerable | v1-fixed |
|---|---|---|
| Brakeman warnings | **17** (9 High, 3 Medium, 5 Weak) | **0** |
| Regression tests passing | 1 of 17 (the one control test) | **17 of 17** (on Rails 6.1 shims, see section D) |
| Flaws Brakeman could not see | 10 | 0 remaining (7 pinned by tests, 3 config-only) |

Severity below is my own illustrative rating for this lab (impact if it were a real bank API),
not Brakeman's confidence level.

## A. What Brakeman found

| ID | Flaw | Where | Brakeman | Severity | Fix |
|---|---|---|---|---|---|
| F-01 | SQL injection: account number interpolated into a `where` string | `accounts#lookup` | SQL, High | High | `find_by(number:)` (bound parameter) |
| F-02 | SQL injection: memo search interpolated into `LIKE` | `transfers#index` | SQL, High | High | Arel `matches` + `sanitize_sql_like` |
| F-03 | OS command injection: `params[:name]` inside `system("gzip ... > ...")` | `statements#export` | Command Injection, High | Critical | No shell. `Zlib::GzipWriter`, server-generated file name |
| F-04 | Path traversal / arbitrary file read via `send_file(join(params[:file]))` | `statements#download` | Path Traversal High + File Access Weak | High | Requested name is only *compared* against the caller's own files, never used to build a path |
| F-05 | Mass assignment: `permit!` lets a signup set `role: "admin"` | `users#create` | Mass Assignment, High | High | Permit `name`, `email`, `password` only |
| F-06 | Unsafe reflection: `params[:type].constantize.new(...)` | `reports#show` | Remote Code Execution, High | High | `case` allow-list of report classes |
| F-07 | Unsalted MD5 for passwords and for API tokens (token = `MD5(email + unix time)`, so guessable) | `user.rb` (3 hits) | Weak Hash, Medium | High | `has_secure_password` (bcrypt), `has_secure_token` |
| F-08 | Open redirect: `redirect_to params[:return_to], allow_other_host: true` | `sessions#destroy` | Redirect, Weak | Low | Redirect targets come from a server-side map |
| F-09 | Broken object-level authorization: `Account.find(params[:id])` (3 places) lets any user read or **spend from** another user's account | `accounts#show`, `statements#export`, `transfers#create` | Unscoped Find, Weak (x3) | Critical | `current_user.accounts.find(...)`; unknown or foreign ids return 404 |
| F-10 | TLS not enforced in production | `production.rb` | Missing Encryption, High | Medium | `force_ssl` and `assume_ssl` |
| F-11 | End-of-life Ruby 3.2 and Rails 7.2 (unplanned: both lapsed by the time of this scan) | `Gemfile` | Unmaintained Dependency, High (x2) | Medium | Rails 8.1, Ruby >= 3.4 |

Note on F-04 and F-09: Brakeman rated the real, exploitable issues only **Weak**. The `UnscopedFind`
warnings are the only static hint at what is, in a bank, the most damaging class of bug.

## B. What Brakeman did not find

Static analysis is pattern matching on data flow. These flaws are real, are in the baseline,
and produced **no warning**. Each is now pinned by a test in `test/integration/security_test.rb`.

| ID | Flaw | Where | Why it slipped past | Severity | Fix | Test |
|---|---|---|---|---|---|---|
| M-01 | Unsafe YAML deserialization: `YAML.unsafe_load(params[:data])` can instantiate arbitrary Ruby objects | `preferences#update` | The Deserialize check covers `YAML.load` and friends; `unsafe_load` produced no warning in this scan | Critical | Parse JSON, allow-list keys and types | `preferences are JSON...` |
| M-02 | `order(params[:sort])` | `accounts#index` | Brakeman deliberately skips `order` on Rails >= 6.1 (see `check_sql.rb`), because Rails rejects non-column strings. Reduced, not zero, risk | Low | Column allow-list | `sort parameter is allow-listed` |
| M-03 | IDOR on profiles: `User.find(params[:id])` returned the whole row, including `password_digest` and `api_token`, so reading a profile means taking the account | `users#show` | `User` has no parent to scope to, so `UnscopedFind` has nothing to say | Critical | Self or admin only; 404 otherwise | `cannot read another user's...` |
| M-04 | Money-logic flaws: negative amounts move money the wrong way, no balance check, no lock (two concurrent requests can double-spend) | `transfers#create` | Business logic; nothing "tainted" reaches a sink | Critical | Validations, ownership scope, `Integer()` parsing, row locks in a transaction, funds check | `negative, zero...`, `overdrafts...` |
| M-05 | Excessive data exposure: `render json: user` / `render json: {user: user}` | `sessions#create`, `users#*` | Serializing a model is not a "sink" | High | `User#public_attributes` | `passwords are bcrypt and login does not leak...` |
| M-06 | Hard-coded `secret_key_base` committed to the repo | `config/initializers/secret_token.rb` | Brakeman's initializer check only fires for Rails 3 style apps. Use a secret scanner (gitleaks, trufflehog) | Medium | Deleted; use `SECRET_KEY_BASE` or credentials | n/a (config) |
| M-07 | `Access-Control-Allow-Origin: *` for every route and header | `cors.rb` | Not a Brakeman check | Low | Deny by default; `ALLOWED_ORIGINS` allow-list | n/a (config) |
| M-08 | Passwords, tokens and emails written to logs; `debug` log level in production | `filter_parameter_logging.rb`, `production.rb` | Not a Brakeman check | Medium | Filter list; `info` level | n/a (config) |
| M-09 | Sequential account numbers (`1000000001, 1000000002...`), which makes `lookup` an enumeration oracle | `account.rb` | Weak randomness in app logic is not detected | Medium | `SecureRandom`, uniqueness retry, masked owner name | `account lookup is parameterized` |
| M-10 | CSV / spreadsheet formula injection through memos in exported statements | `statements#export` | Output encoding for a non-HTML format | Medium | Prefix cells starting with `= + - @` | `exported memos cannot start...` |

**Takeaway:** Brakeman flagged 11 items and covered the injection class well. Of the
five most damaging flaws (F-09, M-01, M-03, M-04, F-03), it caught two, one only as "Weak". Treat it as a
fast first pass in CI, not as the review.

## C. Verification

* `git checkout v0-vulnerable && bundle exec brakeman --run-all-checks` reproduces section A.
* `bin/rails test` runs 17 regression tests. Against `v0-vulnerable` 16 of them fail (the
  17th, "only admins can list users", is a control: that check existed in the baseline).
  Against `v1-fixed` all 17 pass.
* `git checkout v1-fixed && bundle exec brakeman --run-all-checks` reports 0 warnings.
* CI (`.github/workflows/ci.yml`) runs both Brakeman (`--exit-on-warn`) and the tests.

## D. Known limits of this exercise (read before quoting numbers)

* **How it was run.** The scan used Brakeman 8.1.0 from source. The tests were executed on Rails
  6.1.7.3 with small compatibility shims (schema/migration version syntax, `primary_abstract_class`,
  `enable_reloading`), because that was the Rails available in the build sandbox. They have **not** yet been run on
  Rails 8.1. Run `bin/rails test` first; expect to fix at most small version-specific details.
* **No lockfile was committed**, and the scans used a stub lockfile that only named the Rails version. After
  `bundle install`, Brakeman will also run its dependency CVE checks against your real lockfile and may add
  findings that are unrelated to the code.
* **Concurrency (M-04)** is addressed with `lock!` inside a transaction, but there is no concurrent-request test.
  SQLite ignores `FOR UPDATE`; it serialises writers instead. Use PostgreSQL for anything real.
* **Not implemented (would be next):** rate limiting / lockout on `/login` (Rack::Attack), hashing API tokens at
  rest, token expiry and rotation, audit logging, idempotency keys on transfers, constant-time login path to avoid
  user enumeration by timing, DB-level `CHECK (balance_cents >= 0)`.
