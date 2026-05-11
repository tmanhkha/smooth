require 'rails_helper'

RSpec.describe HomeController, type: :request do
  describe 'GET /' do
    it 'shows sign-in and registration links for guests' do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sign in')
      expect(response.body).to include('Get started')
      expect(response.body).not_to include('Log out')
    end

    it 'shows a logout button for authenticated users' do
      user = create(:user)

      post session_path, params: { email_address: user.email_address, password: 'password' }
      follow_redirect!
      expect(response.body).to include('Log out')
      expect(response.body).not_to include('Sign in')
    end
  end
end
