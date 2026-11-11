class PreferencesController < ApplicationController
  ALLOWED_KEYS = %w[locale notifications].freeze

  def update
    parsed = JSON.parse(params[:data].to_s)
    return invalid unless parsed.is_a?(Hash)

    prefs = parsed.slice(*ALLOWED_KEYS)
    return invalid unless valid?(prefs)

    current_user.update!(preferences: prefs.to_json)
    render json: { preferences: prefs }
  rescue JSON::ParserError
    invalid
  end

  private

  def valid?(prefs)
    (!prefs.key?("locale") || prefs["locale"].to_s.match?(/\A[a-z]{2}(-[A-Z]{2})?\z/)) &&
      (!prefs.key?("notifications") || [true, false].include?(prefs["notifications"]))
  end

  def invalid
    render json: { error: "invalid preferences" }, status: :unprocessable_entity
  end
end
