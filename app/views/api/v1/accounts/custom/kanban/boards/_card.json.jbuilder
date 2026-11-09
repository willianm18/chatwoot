json.id card.id
json.column_id card.custom_kanban_column_id
json.title card.title
json.description card.description
json.assignee_id card.assignee_id
json.due_date card.due_date
json.position card.position
json.label_ids card.labels.map(&:id)
