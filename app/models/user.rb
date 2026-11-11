class User < ApplicationRecord
  ROLES = %w[customer teller admin].freeze

  has_secure_password
  has_secure_token :api_token
  has_many :accounts, dependent: :destroy

  before_validation { self.email = email.to_s.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 12 }, allow_nil: true

  def admin?
    role == "admin"
  end

  # The only fields that may ever leave the API. Never serialize the raw record.
  def public_attributes
    slice(:id, :name, :email, :role)
  end
end
