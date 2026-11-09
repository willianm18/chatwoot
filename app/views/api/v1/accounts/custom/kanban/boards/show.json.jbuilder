json.partial! 'api/v1/accounts/custom/kanban/boards/board', board: @board
json.columns @board.columns.includes(cards: :labels) do |column|
  json.partial! 'api/v1/accounts/custom/kanban/boards/column', column: column
  json.cards column.cards do |card|
    json.partial! 'api/v1/accounts/custom/kanban/boards/card', card: card
  end
end
json.labels @board.labels.order(:name) do |label|
  json.partial! 'api/v1/accounts/custom/kanban/boards/label', label: label
end
