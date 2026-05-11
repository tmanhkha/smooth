require 'rails_helper'

RSpec.describe RegistrationsController, type: :request do
  describe 'GET /registrations/new' do
    it 'renders the sign-up page' do
      get new_registrations_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Get started')
      expect(response.body).to include('Confirm password')
    end
  end

  describe 'POST /registrations' do
    it 'creates a user and starts a session' do
      expect {
        post registrations_path, params: {
          user: {
            first_name: 'Mira',
            last_name: 'Okafor',
            email_address: 'mira@example.com',
            password: 'password',
            password_confirmation: 'password'
          }
        }
      }.to change(User, :count).by(1)
        .and change(Session, :count).by(1)

      expect(response).to redirect_to(dashboard_path)
    end

    it 'renders full inline validation messages' do
      post registrations_path, params: {
        user: {
          first_name: '',
          last_name: '',
          email_address: '',
          password: '',
          password_confirmation: ''
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      body = CGI.unescapeHTML(response.body)
      expect(body).to include("First name can't be blank")
      expect(body).to include("Last name can't be blank")
      expect(body).to include("Email address can't be blank")
      expect(body).to include("Password can't be blank")
      expect(response.body).not_to include('full_messages')
    end
  end
end
