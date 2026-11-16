# [fazer.ai fork] Arquiva/desarquiva a conversa. É um estado compartilhado pela conta
# (`conversations.custom_archived`), independente do status: a conversa some das listas
# normais e só aparece na aba "Arquivadas", e não volta sozinha quando chega mensagem nova.
class Api::V1::Accounts::Conversations::CustomArchivesController < Api::V1::Accounts::Conversations::BaseController
  def create
    @conversation.update!(custom_archived: true)
    render partial: 'api/v1/conversations/partials/conversation', formats: [:json], locals: { conversation: @conversation }
  end

  def destroy
    @conversation.update!(custom_archived: false)
    render partial: 'api/v1/conversations/partials/conversation', formats: [:json], locals: { conversation: @conversation }
  end
end
