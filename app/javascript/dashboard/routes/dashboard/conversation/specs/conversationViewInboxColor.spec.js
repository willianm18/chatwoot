import { inboxBubbleStyle } from '../inboxBubbleStyle';

describe('inboxBubbleStyle', () => {
  it('returns the css var and marker class when the inbox has a color', () => {
    expect(inboxBubbleStyle('#9F1239')).toEqual({
      class: 'has-inbox-bubble-color',
      style: { '--inbox-send-bubble': '#9F1239' },
    });
  });

  it('returns no class/style when there is no color', () => {
    expect(inboxBubbleStyle(null)).toEqual({ class: '', style: {} });
  });
});
