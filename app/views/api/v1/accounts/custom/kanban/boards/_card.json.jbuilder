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
json.attachments card.files do |file|
  json.id file.id
  json.filename file.filename.to_s
  json.file_url card.file_url(file)
  json.content_type file.content_type
  json.is_image file.content_type.to_s.start_with?('image/')
end
