import { formatDueDate, isOverdue } from '../cardDateFormat';

describe('cardDateFormat', () => {
  it('formats a date as short day/month', () => {
    expect(formatDueDate('2026-11-14')).toBe('14 Nov');
  });

  it('flags past dates as overdue', () => {
    expect(isOverdue('2000-01-01')).toBe(true);
    expect(isOverdue('2999-01-01')).toBe(false);
  });

  it('handles empty input', () => {
    expect(formatDueDate(null)).toBe('');
    expect(isOverdue(null)).toBe(false);
  });
});
