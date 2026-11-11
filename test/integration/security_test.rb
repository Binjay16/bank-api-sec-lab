require "test_helper"
require "zlib"
require "tmpdir"

# Regression tests: each one pins a flaw that existed in v0-vulnerable.
class SecurityTest < ActionDispatch::IntegrationTest
  setup do
    @alice = User.create!(name: "Alice Demo", email: "alice@example.test", password: "correct-horse-battery")
    @bob   = User.create!(name: "Bob Demo",   email: "bob@example.test",   password: "staple-battery-horse")
    @admin = User.create!(name: "Root Demo",  email: "root@example.test",  password: "admin-battery-horse", role: "admin")
    @a_acct = @alice.accounts.create!(balance_cents: 100_000)
    @b_acct = @bob.accounts.create!(balance_cents: 50_000)
    FileUtils.rm_rf(StatementsController::EXPORT_DIR)
  end

  def auth(user) = { "Authorization" => "Bearer #{user.api_token}" }

  def transfer!(user, from:, amount:, memo: nil, to: @b_acct)
    post "/transfers", headers: auth(user), as: :json,
         params: { from_account_id: from.id, to_number: to.number, amount_cents: amount, memo: memo }
  end

  # --- Mass assignment / crypto / data exposure -------------------------------
  test "signup cannot set role" do
    post "/users", as: :json, params: { user: { name: "Eve", email: "eve@example.test",
                                                 password: "a-long-password-1", role: "admin" } }
    assert_response :created
    assert_equal "customer", User.find_by!(email: "eve@example.test").role
  end

  test "passwords are bcrypt and login does not leak the user row" do
    assert_match(/\A\$2[aby]\$/, @alice.password_digest)
    post "/login", as: :json, params: { email: "alice@example.test", password: "correct-horse-battery" }
    assert_response :success
    body = response.parsed_body
    assert body["token"].present?
    assert_empty body["user"].keys & %w[password_digest api_token preferences]
  end

  test "api tokens are not derivable from email and time" do
    refute_equal Digest::MD5.hexdigest("#{@alice.email}#{Time.now.to_i}"), @alice.api_token
  end

  # --- Object-level authorization (IDOR / BOLA) --------------------------------
  test "cannot read another user's account or profile" do
    get "/accounts/#{@b_acct.id}", headers: auth(@alice)
    assert_response :not_found
    get "/users/#{@bob.id}", headers: auth(@alice)
    assert_response :not_found
  end

  test "only admins can list users" do
    get "/users", headers: auth(@alice)
    assert_response :forbidden
    get "/users", headers: auth(@admin)
    assert_response :success
  end

  # --- Transfer integrity ------------------------------------------------------
  test "cannot move money out of someone else's account" do
    transfer!(@alice, from: @b_acct, amount: 1_000, to: @a_acct)
    assert_response :not_found
    assert_equal 50_000, @b_acct.reload.balance_cents
  end

  test "negative, zero and non-integer amounts are rejected" do
    [-5_000, 0, "abc", "1.5"].each do |bad|
      transfer!(@alice, from: @a_acct, amount: bad)
      assert_response :unprocessable_entity, "amount #{bad.inspect} should be rejected"
    end
    assert_equal 100_000, @a_acct.reload.balance_cents
    assert_equal 50_000,  @b_acct.reload.balance_cents
  end

  test "overdrafts are rejected and a valid transfer moves exactly the amount" do
    transfer!(@alice, from: @a_acct, amount: 100_001)
    assert_response :unprocessable_entity
    transfer!(@alice, from: @a_acct, amount: 25_000, memo: "rent")
    assert_response :created
    assert_equal 75_000, @a_acct.reload.balance_cents
    assert_equal 75_000, @b_acct.reload.balance_cents
  end

  # --- SQL injection -----------------------------------------------------------
  test "account lookup is parameterized" do
    get "/accounts/lookup", headers: auth(@alice), params: { number: "' OR '1'='1" }
    assert_response :not_found
    get "/accounts/lookup", headers: auth(@alice), params: { number: @b_acct.number }
    assert_response :success
    assert_equal "B** D***", response.parsed_body["owner"]
  end

  test "memo search is parameterized" do
    transfer!(@alice, from: @a_acct, amount: 1_000, memo: "rent")
    get "/transfers", headers: auth(@alice), params: { q: "zzz' OR memo LIKE '" }
    assert_response :success
    assert_empty response.parsed_body
    get "/transfers", headers: auth(@alice), params: { q: "ren" }
    assert_equal 1, response.parsed_body.size
  end

  test "sort parameter is allow-listed" do
    get "/accounts", headers: auth(@alice), params: { sort: "balance_cents; DROP TABLE accounts" }
    assert_response :success
    assert_equal 2, Account.count
  end

  # --- Command injection / path traversal / CSV injection ------------------------
  test "export ignores user-supplied names and never shells out with them" do
    marker = File.join(Dir.tmpdir, "pwned-#{SecureRandom.hex(4)}")
    get "/accounts/#{@a_acct.id}/statement/export", headers: auth(@alice),
        params: { name: "x; touch #{marker}" }
    assert_response :success
    refute File.exist?(marker)
    assert_match(/\A\h{32}\.csv\.gz\z/, response.parsed_body["file"])
  end

  test "download is confined to the caller's own exports" do
    get "/accounts/#{@a_acct.id}/statement/export", headers: auth(@alice)
    file = response.parsed_body["file"]
    get "/statements/download", headers: auth(@alice), params: { file: file }
    assert_response :success
    assert_includes Zlib.gunzip(response.body), "date,from,to,amount_cents,memo"

    get "/statements/download", headers: auth(@bob), params: { file: file }
    assert_response :not_found
    get "/statements/download", headers: auth(@alice), params: { file: "../../../../etc/passwd" }
    assert_response :not_found
  end

  test "exported memos cannot start a spreadsheet formula" do
    transfer!(@alice, from: @a_acct, amount: 1_000, memo: "=HYPERLINK(\"http://evil.example\")")
    get "/accounts/#{@a_acct.id}/statement/export", headers: auth(@alice)
    get "/statements/download", headers: auth(@alice), params: { file: response.parsed_body["file"] }
    assert_includes Zlib.gunzip(response.body), "'=HYPERLINK"
  end

  # --- Unsafe deserialization / reflection / redirect ------------------------------
  test "preferences are JSON, allow-listed, and never deserialize objects" do
    put "/preferences", headers: auth(@alice), as: :json,
        params: { data: "--- !ruby/object:Object {}\n" }
    assert_response :unprocessable_entity

    put "/preferences", headers: auth(@alice), as: :json,
        params: { data: { locale: "en", notifications: true, role: "admin" }.to_json }
    assert_response :success
    assert_equal({ "locale" => "en", "notifications" => true }, response.parsed_body["preferences"])
  end

  test "reports are an allow-list, not constantize" do
    get "/reports/Kernel", headers: auth(@alice)
    assert_response :not_found
    get "/reports/monthly_summary", headers: auth(@alice)
    assert_response :success
  end

  test "logout cannot redirect off-site" do
    get "/logout", params: { return_to: "https://evil.example" }
    assert_response :redirect
    refute_match(/evil\.example/, response.location)
  end
end
