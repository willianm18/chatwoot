import { useForwardSelection } from '../useForwardSelection.js';

describe('useForwardSelection', () => {
  beforeEach(() => {
    useForwardSelection().clear();
  });

  it('starts a selection for a conversation with the message checked', () => {
    const selection = useForwardSelection();

    selection.start(501, 77);

    expect(selection.active.value).toBe(true);
    expect(selection.isActiveFor(77)).toBe(true);
    expect(selection.isActiveFor(88)).toBe(false);
    expect(selection.isSelected(501)).toBe(true);
    expect(selection.count.value).toBe(1);
  });

  it('toggles messages on and off', () => {
    const selection = useForwardSelection();
    selection.start(501, 77);

    selection.toggle(502);
    expect(selection.selectedIds.value).toEqual([501, 502]);

    selection.toggle(501);
    expect(selection.selectedIds.value).toEqual([502]);
    expect(selection.isSelected(501)).toBe(false);
  });

  it('drops the previous selection when starting on another conversation', () => {
    const selection = useForwardSelection();
    selection.start(501, 77);
    selection.toggle(502);

    selection.start(900, 88);

    expect(selection.isActiveFor(88)).toBe(true);
    expect(selection.selectedIds.value).toEqual([900]);
  });

  it('clears everything', () => {
    const selection = useForwardSelection();
    selection.start(501, 77);

    selection.clear();

    expect(selection.active.value).toBe(false);
    expect(selection.isActiveFor(77)).toBe(false);
    expect(selection.count.value).toBe(0);
  });
});
