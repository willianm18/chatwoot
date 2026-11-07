import { mount } from '@vue/test-utils';
import SidebarGroupHeader from '../SidebarGroupHeader.vue';

vi.mock('vue-router', () => ({
  useRouter: () => ({
    resolve: to => ({ href: typeof to === 'string' ? to : '/resolved' }),
  }),
}));

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: () => ({ value: 0 }),
}));

const mountHeader = props =>
  mount(SidebarGroupHeader, {
    props: { label: 'Panel', ...props },
    global: { stubs: { Icon: true } },
  });

describe('SidebarGroupHeader', () => {
  describe('external link (fork)', () => {
    it('renders an anchor that opens the href in a new tab', () => {
      const wrapper = mountHeader({ href: 'https://panel.example.com' });
      const anchor = wrapper.find('a');

      expect(anchor.exists()).toBe(true);
      expect(anchor.attributes('href')).toBe('https://panel.example.com');
      expect(anchor.attributes('target')).toBe('_blank');
      expect(anchor.attributes('rel')).toBe('noopener noreferrer');
    });

    it('does not emit toggle on click (lets the browser follow the link)', async () => {
      const wrapper = mountHeader({ href: 'https://panel.example.com' });

      await wrapper.find('a').trigger('click');

      expect(wrapper.emitted('toggle')).toBeUndefined();
    });
  });

  describe('internal route', () => {
    it('keeps the in-app toggle and does not set target/rel', async () => {
      const wrapper = mountHeader({ to: '/inbox' });
      const anchor = wrapper.find('a');

      expect(anchor.attributes('target')).toBeUndefined();
      expect(anchor.attributes('rel')).toBeUndefined();

      await anchor.trigger('click');

      expect(wrapper.emitted('toggle')).toHaveLength(1);
    });
  });
});
