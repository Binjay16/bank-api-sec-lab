# Deny by default: CORS is only enabled for origins listed in ALLOWED_ORIGINS
# (comma-separated), e.g. ALLOWED_ORIGINS=https://app.example.com
allowed = ENV.fetch("ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)

unless allowed.empty?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed)
      resource "*",
               headers: %w[Authorization Content-Type],
               methods: %i[get post put options head],
               max_age: 600
    end
  end
end
