# frozen_string_literal: true

module Custom::InboxCustomColor
  extend ActiveSupport::Concern

  # Canonical palette for the per-inbox color. Keep in sync with the frontend
  # copy in app/javascript/dashboard/constants/customInboxColors.js.
  PALETTE = %w[
    #9F1239 #B91C1C #B45309 #15803D #0F766E
    #0E7490 #1D4ED8 #4338CA #6D28D9 #BE185D
  ].freeze

  included do
    validates :custom_color, inclusion: { in: PALETTE }, allow_nil: true
  end
end
