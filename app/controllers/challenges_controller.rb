class ChallengesController < ApplicationController
  include Notifiable

  skip_before_action :authenticate_user!, only: [:show]

  def new
    @challenge = Challenge.new
  end

  def create
    @challenge = Challenge.new(challenge_params)
    @challenge.price = @challenge.price * 100
    @challenge.challenger_id = current_user.id
    @challenge.acceptor_id = User.find_by(username: params[:challenge][:acceptor]).id
    if params[:challenge][:witness] != ""
      @challenge.witness_id = User.find_by(username: params[:challenge][:witness]).id
    end
    if @challenge.save
      notify(@challenge, handshake_path(@challenge))
      redirect_to handshake_path(@challenge)
    else
      @errors = @challenge.errors.full_messages
      render 'new'
    end
  end

  def show
    @challenge = Challenge.find(params[:id])
    return redirect_to edit_challenge_path(@challenge) if @challenge.not_completed?
    @winner = User.find_by(id: @challenge.winner_id)
    @loser = User.find_by(id: @challenge.loser_id)
  end

  def edit
    @challenge = Challenge.find_by(id: params[:id])
    if @challenge
      return redirect_to handshake_path(@challenge) if !have_already_shaken?(shake_count)
      return redirect_to challenge_path(@challenge) if !@challenge.not_completed?
    else
      render 'shared/_404_cancelled_challenge'
    end
  end

  def update
    @challenge = Challenge.find_by(id: params[:id])
    @challenge.update_attributes(winner_id: params[:challenge][:winner_id], loser_id: params[:challenge][:loser_id])
    @challenge.save
    value = @challenge.price / 100
    # generate dwolla info
    app_token = $dwolla.auths.client
    # witness org funding account location
    root = app_token.get "/"
    bucket_location = root._links.account.href
    bucket = app_token.get "#{bucket_location}/funding-sources"
    bucket_url = bucket._embedded[:"funding-sources"][0][:"_links"][:"self"][:"href"]
    # witness org id
    main = app_token.get bucket_location
    witness_dwolla_id = main.id
    # transfer for each user to the bucket
    # start with challenger
    @challenger = User.find_by(id: @challenge.challenger_id)
    challenger_transfer_request = @challenge.generate_transfer_request(@challenger.dwolla_url, bucket_url, value, witness_dwolla_id)
    challenger_transfer_to_bucket = app_token.post "transfers", challenger_transfer_request
    # -----------------------------------------------
    # acceptor tranfer to bucket
    @acceptor = User.find_by(id: @challenge.acceptor_id)
    acceptor_transfer_request = @challenge.generate_transfer_request(@acceptor.dwolla_url, bucket_url, value, witness_dwolla_id)
    acceptor_transfer_to_bucket = app_token.post "transfers", acceptor_transfer_request
    # -----------------------------------------------
    # transfer fromt the witness bucket to the winner
    @loser = User.find_by(id: @challenge.loser_id)
    @winner = User.find_by(id: @challenge.winner_id)
    pot = (@challenge.price * 2) / 100
    winner_transfer_request = @challenge.generate_transfer_request(bucket_url, @winner.dwolla_url, pot, @winner.dwolla_id)
    winner_transfer = app_token.post "transfers", winner_transfer_request
    # -----------------------------------------------
    render 'show'
  end

  def destroy
    @challenge = Challenge.find_by(id: params[:id])
    if @challenge.witness.id == session[:user_id]
      @challenge.destroy
      redirect_to current_user
    else
      @errors = ["Only the witness can cancel a challenge"]
      render "edit"
    end
  end

  private
    def challenge_params
      params.require(:challenge).permit(:description, :price)
    end

end
