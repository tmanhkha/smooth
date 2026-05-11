require 'rails_helper'

RSpec.describe Current, type: :model do
  describe '.user' do
    it 'delegates to the current session user' do
      user = create(:user)
      session = user.sessions.create!

      described_class.session = session

      expect(described_class.user).to eq(user)
    ensure
      described_class.reset
    end

    it 'returns nil when no session is set' do
      described_class.session = nil

      expect(described_class.user).to be_nil
    ensure
      described_class.reset
    end
  end
end
