import { mount } from '@vue/test-utils';
import TabsItem from '../TabsItem.vue';

const provide = { activeIndex: { value: 0 }, updateActiveIndex: () => {} };

describe('TabsItem', () => {
  it('renders an icon span when icon prop is set', () => {
    const wrapper = mount(TabsItem, {
      props: { index: 0, name: 'Arquivadas', icon: 'i-lucide-archive' },
      global: { provide, directives: { tooltip: () => {} } },
    });
    expect(wrapper.find('.i-lucide-archive').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('Arquivadas');
  });

  it('renders the name when no icon', () => {
    const wrapper = mount(TabsItem, {
      props: { index: 0, name: 'Minhas' },
      global: { provide, directives: { tooltip: () => {} } },
    });
    expect(wrapper.text()).toContain('Minhas');
  });
});
