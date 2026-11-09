import { mutations, actions } from '../kanban';
import types from '../../../mutation-types';

describe('kanban mutations', () => {
  it('SET_KANBAN_CURRENT_BOARD stores the board', () => {
    const state = { currentBoard: null };
    const board = { id: 1, columns: [] };
    mutations[types.SET_KANBAN_CURRENT_BOARD](state, board);
    expect(state.currentBoard).toEqual(board);
  });

  it('DELETE_KANBAN_BOARD removes by id', () => {
    const state = { boards: [{ id: 1 }, { id: 2 }] };
    mutations[types.DELETE_KANBAN_BOARD](state, 1);
    expect(state.boards).toEqual([{ id: 2 }]);
  });

  it('ADD_KANBAN_BOARD appends', () => {
    const state = { boards: [] };
    mutations[types.ADD_KANBAN_BOARD](state, { id: 9 });
    expect(state.boards).toEqual([{ id: 9 }]);
  });
});

describe('kanban onBoardUpdated', () => {
  it('refetches when the open board matches', () => {
    const dispatch = vi.fn();
    actions.onBoardUpdated({ state: { currentBoard: { id: 5 } }, dispatch }, 5);
    expect(dispatch).toHaveBeenCalledWith('fetchBoard', 5);
  });

  it('ignores events for other boards', () => {
    const dispatch = vi.fn();
    actions.onBoardUpdated({ state: { currentBoard: { id: 5 } }, dispatch }, 9);
    expect(dispatch).not.toHaveBeenCalled();
  });
});
