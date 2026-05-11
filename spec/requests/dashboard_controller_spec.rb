require 'rails_helper'

RSpec.describe DashboardController, type: :request do
  describe 'GET /dashboard' do
    it 'redirects guests to sign in' do
      get dashboard_path

      expect(response).to redirect_to(new_session_path)
    end

    it 'renders dashboard for authenticated users' do
      user = create(:user)
      post session_path, params: { email_address: user.email_address, password: 'password' }

      get dashboard_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Welcome back, Mira.')
      expect(response.body).to include('Overview')
      expect(response.body).to include("Today's sessions")
    end
  end
end
