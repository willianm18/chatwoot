# [fazer.ai fork] Forwards one or more messages from the current native WhatsApp conversation
# to another contact, re-sending the content (and media) through the normal outgoing pipeline.
# The heavy lifting lives in Custom::Messages::ForwardService.
class Api::V1::Accounts::Conversations::ForwardsController < Api::V1::Accounts::Conversations::BaseController
  def create
    target_contact = Current.account.contacts.find(permitted_params[:target_contact_id])
    target = Custom::Messages::ForwardService.new(
      conversation: @conversation,
      message_ids: Array(permitted_params[:message_ids]),
      target_contact: target_contact,
      user: Current.user
    ).perform

    render json: { conversation_id: target.display_id }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def permitted_params
    params.permit(:conversation_id, :target_contact_id, message_ids: [])
  end
end
