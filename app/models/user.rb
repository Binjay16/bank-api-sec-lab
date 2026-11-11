require "digest"

class User < ApplicationRecord
  has_many :accounts, dependent: :destroy

  before_create :set_token

  def password=(plain)
    self.password_digest = Digest::MD5.hexdigest(plain.to_s)
  end

  def authenticate(plain)
    password_digest == Digest::MD5.hexdigest(plain.to_s)
  end

  private

  def set_token
    self.api_token = Digest::MD5.hexdigest("#{email}#{Time.now.to_i}")
  end
end
