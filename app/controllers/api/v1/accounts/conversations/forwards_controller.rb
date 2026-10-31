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

  # Contacts reachable for a forward: a forward re-sends through the source inbox's own
  # WhatsApp number, so only contacts that already have a thread on that inbox can receive
  # one. Scoping the search here also disambiguates same-name contacts that live on other
  # inboxes, which the account-wide contact search cannot.
  def contacts
    query = params[:q].to_s.strip
    @contacts = if query.blank?
                  Contact.none
                else
                  @conversation.inbox.contacts
                               .where('contacts.name ILIKE :q OR contacts.phone_number ILIKE :q', q: "%#{query}%")
                               .where.not(phone_number: [nil, ''])
                               .distinct
                               .order(:name)
                               .limit(20)
                end
    render json: { payload: @contacts.map { |contact| forwardable_contact_json(contact) } }
  end

  private

  def forwardable_contact_json(contact)
    {
      id: contact.id,
      name: contact.name,
      phone_number: contact.phone_number,
      email: contact.email,
      thumbnail: contact.avatar_url
    }
  end

  def permitted_params
    params.permit(:conversation_id, :target_contact_id, message_ids: [])
  end
end
