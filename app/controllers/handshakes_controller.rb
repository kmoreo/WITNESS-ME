class HandshakesController < ApplicationController
  before_action :reroute?, only: [:show]

  def create
  end

  def show

  end

  private
    def reroute?
      @challenge = Challenge.find(params[:id])
      cookies.signed[:witness_id] = @challenge.witness_id
      @challenger = @challenge.challenger
      @acceptor = @challenge.acceptor
      return redirect_to root_path if !check_id(current_user)
      return redirect_to user_path(current_user) if have_already_shaken?(shake_count)
    end

    def check_id(user)
      return (user == @challenge.challenger || user == @challenge.witness || user == @challenge.acceptor)
    end

    # def shake_count
    #   shakes = Handshake.where(challenge_id: @challenge.id).count
    #   return shakes
    # end

    # def have_already_shaken?(count)
    #   return count >= 2
    # end
end
