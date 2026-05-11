class OrganizationMembership < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  enum :role, { member: 0, manager: 1, admin: 2, owner: 3 }, validate: true
end
