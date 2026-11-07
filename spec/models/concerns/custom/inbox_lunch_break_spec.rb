require 'rails_helper'

RSpec.describe Custom::InboxLunchBreak do
  # Default working hours seeded on create are Mon-Fri 09:00-17:00, closed on
  # weekends. 2020-10-26 is a Monday. Specs run with TZ=UTC.
  let(:lunch) { { enabled: true, start_hour: 12, start_minutes: 0, end_hour: 13, end_minutes: 0 } }
  let(:inbox) do
    create(:inbox, working_hours_enabled: true, out_of_office_message: 'Away', timezone: 'UTC', custom_lunch_break: lunch)
  end

  describe '#out_of_office?' do
    it 'is out of office during the lunch window on a working day' do
      travel_to '2020-10-26 12:30:00 UTC'
      expect(inbox.out_of_office?).to be true
    end

    it 'is working within business hours but outside the lunch window' do
      travel_to '2020-10-26 10:00:00 UTC'
      expect(inbox.out_of_office?).to be false
    end

    it 'stays out of office outside business hours regardless of lunch' do
      travel_to '2020-10-25 12:30:00 UTC' # Sunday
      expect(inbox.out_of_office?).to be true
    end

    it 'ignores the lunch window when the break is disabled' do
      inbox.update!(custom_lunch_break: lunch.merge(enabled: false))
      travel_to '2020-10-26 12:30:00 UTC'
      expect(inbox.out_of_office?).to be false
    end

    it 'ignores the lunch window when business hours are disabled' do
      inbox.update!(working_hours_enabled: false)
      travel_to '2020-10-26 12:30:00 UTC'
      expect(inbox.out_of_office?).to be false
    end

    it 'evaluates the lunch window in the inbox timezone' do
      inbox.update!(timezone: 'America/Sao_Paulo') # UTC-3 in Oct 2020
      travel_to '2020-10-26 15:30:00 UTC' # 12:30 local -> lunch
      expect(inbox.out_of_office?).to be true

      travel_to '2020-10-26 12:30:00 UTC' # 09:30 local -> working
      expect(inbox.out_of_office?).to be false
    end
  end

  describe 'validation' do
    it 'rejects a lunch window whose end is not after the start' do
      inbox.custom_lunch_break = lunch.merge(end_hour: 12, end_minutes: 0)
      expect(inbox).not_to be_valid
      expect(inbox.errors[:custom_lunch_break]).to be_present
    end

    it 'rejects out-of-range hours' do
      inbox.custom_lunch_break = lunch.merge(start_hour: 24)
      expect(inbox).not_to be_valid
    end
  end
end
