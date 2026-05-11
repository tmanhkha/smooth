require 'rails_helper'

RSpec.describe OrganizationMembership, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:role).with_values(member: 0, manager: 1, admin: 2, owner: 3) }
  end
end
