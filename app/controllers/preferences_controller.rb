class PreferencesController < ApplicationController
  def update
    prefs = YAML.unsafe_load(params[:data].to_s)
    current_user.update!(preferences: prefs.to_json)
    render json: { preferences: prefs }
  end
end
