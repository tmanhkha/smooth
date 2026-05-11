require 'rails_helper'

RSpec.describe SessionsController, type: :request do
  describe 'GET /session/new' do
    it 'renders the sign-in page' do
      get new_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Welcome back')
      expect(response.body).to include('Forgot password?')
    end
  end

  describe 'POST /session' do
    it 'signs in with valid credentials' do
      user = create(:user)

      expect {
        post session_path, params: { email_address: user.email_address, password: 'password' }
      }.to change(Session, :count).by(1)

      expect(response).to redirect_to(root_url)
    end

    it 'renders inline errors for invalid credentials' do
      post session_path, params: { email_address: 'missing@example.com', password: 'wrong-password' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('id="session-error"')
      expect(response.body).to include('Try another email address or password.')
      expect(response.body).not_to include('id="alert"')
    end
  end

  describe 'DELETE /session' do
    it 'logs out and redirects with a notice' do
      user = create(:user)
      post session_path, params: { email_address: user.email_address, password: 'password' }

      delete session_path

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include('You have been logged out')
      expect(response.body).not_to include('id="session-error"')
    end
  end
end
