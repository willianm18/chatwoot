json.id card.id
json.column_id card.custom_kanban_column_id
json.title card.title
json.description card.description
json.assignee_id card.assignee_id
json.due_date card.due_date
json.position card.position
json.label_ids card.labels.map(&:id)
json.comments card.comments.includes(:user) do |comment|
  json.id comment.id
  json.author_id comment.user_id
  json.author_name comment.user.name
  json.content comment.content
  json.created_at comment.created_at
end
