import { format, parseISO, isPast, isToday } from 'date-fns';

// [fazer.ai fork] Short due-date label for a card face, e.g. "14 Nov".
export const formatDueDate = dateString => {
  if (!dateString) return '';
  return format(parseISO(dateString), 'd MMM');
};

// A due date is overdue once its day is in the past (today is still on time).
export const isOverdue = dateString => {
  if (!dateString) return false;
  const date = parseISO(dateString);
  return isPast(date) && !isToday(date);
};
