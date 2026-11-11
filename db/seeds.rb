# Demo data for the lab only. These are throwaway credentials.
alice = User.create!(name: "Alice Demo", email: "alice@example.test", password: "demo-password-1")
bob   = User.create!(name: "Bob Demo",   email: "bob@example.test",   password: "demo-password-2")
User.create!(name: "Admin Demo", email: "admin@example.test", password: "demo-password-3", role: "admin")

alice.accounts.create!(kind: "checking", balance_cents: 250_000)
bob.accounts.create!(kind: "checking", balance_cents: 90_000)
