import { mount } from '@vue/test-utils';
import { withFullI18n } from 'test-i18n';
import ForwardSelectionBar from '../ForwardSelectionBar.vue';
import { useForwardSelection } from '../useForwardSelection.js';

withFullI18n();

describe('ForwardSelectionBar', () => {
  beforeEach(() => {
    useForwardSelection().clear();
  });

  it('shows how many messages are selected', () => {
    const selection = useForwardSelection();
    selection.start(501, 77);
    selection.toggle(502);

    const wrapper = mount(ForwardSelectionBar);

    expect(wrapper.text()).toContain('2');
  });

  it('emits forward with the triggering event', async () => {
    useForwardSelection().start(501, 77);
    const wrapper = mount(ForwardSelectionBar);

    await wrapper.findAll('button')[1].trigger('click');

    expect(wrapper.emitted('forward')).toBeTruthy();
  });

  it('cancels the selection', async () => {
    const selection = useForwardSelection();
    selection.start(501, 77);
    const wrapper = mount(ForwardSelectionBar);

    await wrapper.findAll('button')[0].trigger('click');

    expect(selection.active.value).toBe(false);
  });

  it('cancels the selection on Escape', async () => {
    const selection = useForwardSelection();
    selection.start(501, 77);
    mount(ForwardSelectionBar, { attachTo: document.body });

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(selection.active.value).toBe(false);
  });
});
