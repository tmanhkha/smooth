require 'rails_helper'

RSpec.describe PasswordsController, type: :request do
  describe 'GET /passwords/new' do
    it 'renders the password reset request page' do
      get new_password_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Password reset')
      expect(response.body).to include('Email reset instructions')
    end
  end

  describe 'POST /passwords' do
    it 'redirects to sign in after requesting reset instructions' do
      create(:user, email_address: 'mira@example.com')

      post passwords_path, params: { email_address: 'mira@example.com' }

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect(response.body).to include('Password reset instructions sent')
    end
  end

  describe 'GET /passwords/:token/edit' do
    it 'renders the password edit page for a valid token' do
      user = create(:user)

      get edit_password_path(user.password_reset_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New password')
      expect(response.body).to include('Save password')
    end
  end

  describe 'PUT /passwords/:token' do
    it 'updates the password and clears sessions' do
      user = create(:user)
      user.sessions.create!

      put password_path(user.password_reset_token), params: {
        password: 'new-password',
        password_confirmation: 'new-password'
      }

      expect(response).to redirect_to(new_session_path)
      expect(user.sessions.reload).to be_empty
      expect(user.reload.authenticate('new-password')).to eq(user)
    end

    it 'renders inline errors when passwords do not match' do
      user = create(:user)

      put password_path(user.password_reset_token), params: {
        password: 'new-password',
        password_confirmation: 'different-password'
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('id="password-update-error"')
      expect(CGI.unescapeHTML(response.body)).to include("Password confirmation doesn't match Password")
    end
  end
end
