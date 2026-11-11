require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # TLS everywhere (assumes TLS is terminated at a trusted proxy/load balancer).
  config.assume_ssl = true
  config.force_ssl  = true

  # No debug logging in production; secrets come from ENV["SECRET_KEY_BASE"] or credentials.
  config.log_level = :info
  config.active_support.report_deprecations = false
end
