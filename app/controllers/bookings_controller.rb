class BookingsController < ApplicationController
  def show
    @user = params[:user]

    @slots_by_day = {
      0 => [],
      1 => %w[9:00 9:30 10:00],
      2 => %w[9:00 11:00],
      3 => %w[10:00 14:00],
      4 => %w[9:00 13:00],
      5 => ["9:00"],
      6 => []
    }

    @today = Date.current
  end
end
