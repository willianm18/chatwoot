import { defineComponent, ref } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { withFullI18n } from 'test-i18n';
import { createForwardableContactSearcher } from '../forwardContactSearch.js';
import ForwardWhatsappPanel from '../ForwardWhatsappPanel.vue';
import { provideMessageContext } from '../../provider.js';

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

const mountPanel = ({ message = {} } = {}) => {
  const forwardMessages = vi.fn().mockResolvedValue({});
  const store = createStore({ actions: { forwardMessages } });
  const context = {
    id: 501,
    content: 'Comprovante',
    attachments: [],
    conversationId: 77,
    ...message,
  };
  const Host = defineComponent({
    components: { ForwardWhatsappPanel },
    // Re-emitted from the inline string template below, which eslint-plugin-vue
    // cannot statically parse, so the declaration looks unused to the linter.
    // eslint-disable-next-line vue/no-unused-emit-declarations
    emits: ['close'],
    setup() {
      provideMessageContext(
        Object.fromEntries(
          Object.entries(context).map(([key, value]) => [key, ref(value)])
        )
      );
    },
    template:
      '<ForwardWhatsappPanel :x="10" :y="20" @close="$emit(\'close\')" />',
  });
  const wrapper = mount(Host, {
    attachTo: document.body,
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

  it('forwards to the chosen contact and closes', async () => {
    const { wrapper, forwardMessages } = mountPanel();

    await wrapper.find('input').setValue('jane');
    await new Promise(resolve => {
      setTimeout(resolve, 450);
    });
    await flushPromises();

    await wrapper.findAll('button')[0].trigger('click');
    await flushPromises();

    expect(forwardMessages).toHaveBeenCalledWith(expect.anything(), {
      conversationId: 77,
      messageIds: [501],
      targetContactId: 99,
    });
    expect(wrapper.emitted('close')).toBeTruthy();
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
