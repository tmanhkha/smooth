class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  validates :email_address, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :first_name, :last_name, :email_address, :password, presence: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
