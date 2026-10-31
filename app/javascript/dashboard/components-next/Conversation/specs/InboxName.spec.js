import { mount } from '@vue/test-utils';
import InboxName from '../InboxName.vue';

const mountWith = inbox =>
  mount(InboxName, {
    props: { inbox },
    global: { stubs: { ChannelIcon: true } },
  });

describe('InboxName', () => {
  it('tints the name when the inbox has a custom color', () => {
    const wrapper = mountWith({ name: 'Ágeis', custom_color: '#9F1239' });
    const span = wrapper.find('span');
    expect(span.attributes('style')).toContain('color: rgb(159, 18, 57)');
    expect(span.attributes('style')).toContain('background-color');
    expect(span.classes()).toContain('rounded-full');
  });

  it('keeps the default style without a custom color', () => {
    const wrapper = mountWith({ name: 'Ágeis' });
    const span = wrapper.find('span');
    expect(span.classes()).not.toContain('rounded-full');
  });
});
