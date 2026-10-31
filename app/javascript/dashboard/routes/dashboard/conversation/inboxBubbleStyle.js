// Derives the wrapper class + CSS var used to recolor the outgoing (agent)
// message bubbles with the conversation inbox color. Kept pure for testing.
export const inboxBubbleStyle = customColor => {
  if (!customColor) return { class: '', style: {} };
  return {
    class: 'has-inbox-bubble-color',
    style: { '--inbox-send-bubble': customColor },
  };
};
