import { mount, flushPromises } from '@vue/test-utils';
import { withFullI18n } from 'test-i18n';
import ConversationForwardOverlay from '../ConversationForwardOverlay.vue';
import { useForwardSelection } from '../useForwardSelection.js';

withFullI18n();

const BAR = { name: 'ForwardSelectionBar' };
const PANEL = { name: 'ForwardWhatsappPanel' };

const stubs = {
  // Render the bar's Teleport in place; a real teleport to body throws in jsdom on unmount.
  teleport: true,
  ForwardSelectionBar: {
    name: 'ForwardSelectionBar',
    template:
      '<button @click="$emit(\'forward\', { clientX: 0, clientY: 0 })">bar</button>',
  },
  ForwardWhatsappPanel: {
    name: 'ForwardWhatsappPanel',
    props: ['x', 'y', 'conversationId', 'messageIds', 'previewText'],
    template: '<button @click="$emit(\'forwarded\')">panel</button>',
  },
};

const mountOverlay = () =>
  mount(ConversationForwardOverlay, {
    attachTo: document.body,
    props: { currentChat: { messages: [] } },
    global: { stubs },
  });

describe('ConversationForwardOverlay', () => {
  beforeEach(() => {
    useForwardSelection().clear();
    document.body.innerHTML = '';
  });

  it('shows the bar only while a selection is active', async () => {
    const wrapper = mountOverlay();
    expect(wrapper.findComponent(BAR).exists()).toBe(false);

    useForwardSelection().start(501, 77);
    await flushPromises();

    expect(wrapper.findComponent(BAR).exists()).toBe(true);
  });

  it('passes the selected ids to the panel and clears on success', async () => {
    useForwardSelection().start(501, 77);
    const wrapper = mountOverlay();

    await wrapper.findComponent(BAR).trigger('click');
    await flushPromises();

    const panel = wrapper.findComponent(PANEL);
    expect(panel.props('conversationId')).toBe(77);
    expect(panel.props('messageIds')).toEqual([501]);

    await panel.trigger('click');
    await flushPromises();

    expect(useForwardSelection().active.value).toBe(false);
  });
});
