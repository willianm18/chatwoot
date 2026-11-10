json.partial! 'api/v1/accounts/custom/kanban/boards/board', board: @board
json.columns @board.columns.includes(cards: %i[labels assignees]) do |column|
  json.partial! 'api/v1/accounts/custom/kanban/boards/column', column: column
  json.cards column.cards do |card|
    json.partial! 'api/v1/accounts/custom/kanban/boards/card', card: card
  end
end
json.labels @board.labels.order(:name) do |label|
  json.partial! 'api/v1/accounts/custom/kanban/boards/label', label: label
end
json.members @board.members.includes(:user) do |member|
  json.user_id member.user_id
  json.name member.user.name
  json.thumbnail member.user.avatar_url
end
