import { mount } from '@vue/test-utils';
import InboxColorPicker from '../InboxColorPicker.vue';
import { INBOX_COLOR_PALETTE } from 'dashboard/constants/customInboxColors';

const globalConfig = {
  mocks: { $t: key => key },
};

describe('InboxColorPicker', () => {
  it('renders a swatch per palette color plus the "no color" option', () => {
    const wrapper = mount(InboxColorPicker, {
      props: { modelValue: null },
      global: globalConfig,
    });
    expect(wrapper.findAll('[data-testid="color-swatch"]')).toHaveLength(
      INBOX_COLOR_PALETTE.length
    );
    expect(wrapper.find('[data-testid="color-none"]').exists()).toBe(true);
  });

  it('emits the chosen color', async () => {
    const wrapper = mount(InboxColorPicker, {
      props: { modelValue: null },
      global: globalConfig,
    });
    await wrapper.findAll('[data-testid="color-swatch"]')[2].trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([
      INBOX_COLOR_PALETTE[2],
    ]);
  });

  it('emits null when "no color" is chosen', async () => {
    const wrapper = mount(InboxColorPicker, {
      props: { modelValue: INBOX_COLOR_PALETTE[0] },
      global: globalConfig,
    });
    await wrapper.find('[data-testid="color-none"]').trigger('click');
    expect(wrapper.emitted('update:modelValue')[0]).toEqual([null]);
  });
});
