require 'rails_helper'

RSpec.describe PasswordsMailer, type: :mailer do
  describe '#reset' do
    it 'sends password reset instructions to the user' do
      user = create(:user, email_address: 'mira@example.com')

      email = described_class.reset(user)

      expect(email.subject).to eq('Reset your password')
      expect(email.to).to eq(['mira@example.com'])
      expect(email.from).to eq(['from@example.com'])
      expect(email.html_part.body.encoded).to include('http://example.com/passwords/')
      expect(email.html_part.body.encoded).to include('/edit')
      expect(email.text_part.body.encoded).to include('http://example.com/passwords/')
      expect(email.text_part.body.encoded).to include('/edit')
      expect(email.text_part.body.encoded).to include('This link will expire')
    end
  end
end
