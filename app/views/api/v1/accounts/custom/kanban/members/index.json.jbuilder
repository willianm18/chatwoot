json.payload do
  json.array! @members do |member|
    json.id member.id
    json.user_id member.user_id
    json.name member.user.name
    json.owner member.user_id == @current_board.created_by_id
  end
end
