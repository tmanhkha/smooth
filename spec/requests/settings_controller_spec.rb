require 'rails_helper'

RSpec.describe SettingsController, type: :request do
  describe 'GET /settings' do
    it 'redirects guests to sign in' do
      get settings_path

      expect(response).to redirect_to(new_session_path)
    end

    it 'renders settings for authenticated users' do
      user = create(:user)
      post session_path, params: { email_address: user.email_address, password: 'password' }

      get settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Account &amp; preferences')
      expect(response.body).to include('Email reminders')
      expect(response.body).to include('Danger zone')
    end
  end
end
