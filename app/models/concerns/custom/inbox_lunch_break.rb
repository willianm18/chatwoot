# frozen_string_literal: true

# Per-inbox lunch break: a single daily window (same every weekday) that, while
# business hours are enabled, is treated as "closed" so the existing
# out-of-office message fires during lunch. Stored in the `custom_lunch_break`
# jsonb column as { enabled, start_hour, start_minutes, end_hour, end_minutes }.
module Custom::InboxLunchBreak
  extend ActiveSupport::Concern

  included do
    validate :lunch_break_within_bounds, if: :lunch_break_enabled?
  end

  # Extends OutOfOffisable#out_of_office?: still closed outside business hours,
  # and additionally closed while inside the lunch window.
  def out_of_office?
    return true if super

    within_lunch_break_now?
  end

  def lunch_break
    (custom_lunch_break || {}).with_indifferent_access
  end

  def lunch_break_enabled?
    working_hours_enabled? && ActiveModel::Type::Boolean.new.cast(lunch_break[:enabled])
  end

  private

  def within_lunch_break_now?
    return false unless lunch_break_enabled?

    now = Time.zone.now.in_time_zone(timezone)
    now.between?(lunch_break_time(now, :start_hour, :start_minutes), lunch_break_time(now, :end_hour, :end_minutes))
  end

  def lunch_break_time(now, hour_key, minutes_key)
    now.change(hour: lunch_break[hour_key].to_i, min: lunch_break[minutes_key].to_i)
  end

  def lunch_break_within_bounds
    unless (0..23).cover?(lunch_break[:start_hour].to_i) && (0..23).cover?(lunch_break[:end_hour].to_i) &&
           (0..59).cover?(lunch_break[:start_minutes].to_i) && (0..59).cover?(lunch_break[:end_minutes].to_i)
      errors.add(:custom_lunch_break, 'has invalid lunch break hours')
      return
    end

    start_total = (lunch_break[:start_hour].to_i * 60) + lunch_break[:start_minutes].to_i
    end_total = (lunch_break[:end_hour].to_i * 60) + lunch_break[:end_minutes].to_i
    errors.add(:custom_lunch_break, 'lunch break end must be after start') if end_total <= start_total
  end
end
