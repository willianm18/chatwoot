import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { withFullI18n } from 'test-i18n';
import { createForwardableContactSearcher } from '../forwardContactSearch.js';
import { useForwardSelection } from '../useForwardSelection.js';
import ForwardWhatsappPanel from '../ForwardWhatsappPanel.vue';

vi.mock('../forwardContactSearch.js', () => ({
  createForwardableContactSearcher: vi.fn(),
}));

const alertSpy = vi.fn();
vi.mock('dashboard/composables', () => ({
  useAlert: (...args) => alertSpy(...args),
}));

withFullI18n();

const stubs = {
  ContextMenu: {
    name: 'ContextMenu',
    props: ['x', 'y', 'closeOnFocusOut'],
    template: '<div><slot /></div>',
  },
  Avatar: {
    name: 'Avatar',
    props: ['name', 'src', 'size'],
    template: '<div />',
  },
};

const mountPanel = ({ props = {} } = {}) => {
  const forwardMessages = vi.fn().mockResolvedValue({});
  const store = createStore({ actions: { forwardMessages } });
  const wrapper = mount(ForwardWhatsappPanel, {
    attachTo: document.body,
    props: {
      x: 10,
      y: 20,
      conversationId: 77,
      messageIds: [501],
      previewText: 'Comprovante',
      ...props,
    },
    global: { plugins: [store], stubs },
  });
  return { wrapper, forwardMessages };
};

describe('ForwardWhatsappPanel', () => {
  let searchContacts;

  beforeEach(() => {
    alertSpy.mockClear();
    searchContacts = vi.fn().mockResolvedValue([
      { id: 99, name: 'Jane Doe', phoneNumber: '+5511999990000' },
      { id: 100, name: 'No Phone', phoneNumber: null, email: 'np@x.com' },
    ]);
    createForwardableContactSearcher.mockReturnValue(searchContacts);
  });

  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('scopes the contact search to the source conversation', () => {
    mountPanel();

    expect(createForwardableContactSearcher).toHaveBeenCalledWith(77);
  });

  it('lets the panel close on outside click (no scroll-locking focus-out)', () => {
    const { wrapper } = mountPanel();

    const contextMenu = wrapper.findComponent({ name: 'ContextMenu' });
    expect(contextMenu.props('closeOnFocusOut')).not.toBe(false);
  });

  it('summarizes the count when more than one message is selected', () => {
    const { wrapper } = mountPanel({ props: { messageIds: [501, 502, 503] } });

    expect(wrapper.text()).toContain('3');
  });

  it('searches contacts when typing and renders results', async () => {
    const { wrapper } = mountPanel();

    await wrapper.find('input').setValue('jane');
    await new Promise(resolve => {
      setTimeout(resolve, 450);
    });
    await flushPromises();

    expect(searchContacts).toHaveBeenCalledWith('jane');
    expect(wrapper.text()).toContain('Jane Doe');
  });

  it('forwards the selected messages to the chosen contact', async () => {
    const { wrapper, forwardMessages } = mountPanel({
      props: { messageIds: [501, 502] },
    });

    await wrapper.find('input').setValue('jane');
    await new Promise(resolve => {
      setTimeout(resolve, 450);
    });
    await flushPromises();

    await wrapper.findAll('button')[0].trigger('click');
    await flushPromises();

    expect(forwardMessages).toHaveBeenCalledWith(expect.anything(), {
      conversationId: 77,
      messageIds: [501, 502],
      targetContactId: 99,
    });
    expect(wrapper.emitted('forwarded')).toBeTruthy();
  });

  it('clears the selection after a successful forward', async () => {
    useForwardSelection().start(501, 77);
    const { wrapper } = mountPanel();

    await wrapper.find('input').setValue('jane');
    await new Promise(resolve => {
      setTimeout(resolve, 450);
    });
    await flushPromises();

    await wrapper.findAll('button')[0].trigger('click');
    await flushPromises();

    expect(useForwardSelection().active.value).toBe(false);
  });

  it('refuses a contact without a phone number', async () => {
    const { wrapper, forwardMessages } = mountPanel();

    await wrapper.find('input').setValue('no');
    await new Promise(resolve => {
      setTimeout(resolve, 450);
    });
    await flushPromises();

    await wrapper.findAll('button')[1].trigger('click');
    await flushPromises();

    expect(forwardMessages).not.toHaveBeenCalled();
    expect(alertSpy).toHaveBeenCalled();
  });
});
