# frozen_string_literal: true

# [fazer.ai fork] Wires Kanban boards onto Account without editing the upstream model body.
module Custom::AccountKanban
  extend ActiveSupport::Concern

  included do
    has_many :kanban_boards, class_name: 'Custom::Kanban::Board', dependent: :destroy
  end
end
