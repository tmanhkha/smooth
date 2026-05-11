require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  it 'connects when a signed session cookie is present' do
    user = create(:user)
    session = user.sessions.create!

    cookies.signed[:session_id] = session.id
    connect '/cable'

    expect(connection.current_user).to eq(user)
  end

  it 'rejects connections without a valid signed session cookie' do
    expect { connect '/cable' }.to have_rejected_connection
  end
end
