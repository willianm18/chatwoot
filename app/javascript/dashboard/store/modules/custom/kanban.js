import { throwErrorMessage } from 'dashboard/store/utils/api';
import types from '../../mutation-types';
import KanbanAPI from '../../../api/custom/kanban';

// [fazer.ai fork] Native team-tasks Kanban store. Mutating actions refetch the
// current board after the write; onBoardUpdated handles real-time cable events.
const state = {
  boards: [],
  currentBoard: null,
  uiFlags: { fetchingList: false, fetchingItem: false, creatingItem: false },
};

export const getters = {
  getBoards: _state => _state.boards,
  getCurrentBoard: _state => _state.currentBoard,
  getUIFlags: _state => _state.uiFlags,
};

export const actions = {
  fetchBoards: async ({ commit }) => {
    commit(types.SET_KANBAN_UI_FLAG, { fetchingList: true });
    try {
      const { data } = await KanbanAPI.get();
      commit(types.SET_KANBAN_BOARDS, data.payload);
    } finally {
      commit(types.SET_KANBAN_UI_FLAG, { fetchingList: false });
    }
  },
  createBoard: async ({ commit }, payload) => {
    commit(types.SET_KANBAN_UI_FLAG, { creatingItem: true });
    try {
      const { data } = await KanbanAPI.create({ board: payload });
      commit(types.ADD_KANBAN_BOARD, data);
      return data;
    } catch (error) {
      return throwErrorMessage(error);
    } finally {
      commit(types.SET_KANBAN_UI_FLAG, { creatingItem: false });
    }
  },
  deleteBoard: async ({ commit }, id) => {
    await KanbanAPI.delete(id);
    commit(types.DELETE_KANBAN_BOARD, id);
  },
  fetchBoard: async ({ commit }, id) => {
    commit(types.SET_KANBAN_UI_FLAG, { fetchingItem: true });
    try {
      const { data } = await KanbanAPI.show(id);
      commit(types.SET_KANBAN_CURRENT_BOARD, data);
    } finally {
      commit(types.SET_KANBAN_UI_FLAG, { fetchingItem: false });
    }
  },
  // vuedraggable has already moved the card between the column arrays (bound via
  // :list); here we only persist the new order and reconcile from the server on
  // failure.
  moveCard: async (
    { state: s, dispatch },
    { cardId, toColumnId, position }
  ) => {
    const boardId = s.currentBoard?.id;
    try {
      await KanbanAPI.moveCard(boardId, cardId, {
        columnId: toColumnId,
        position,
      });
    } catch (error) {
      await dispatch('fetchBoard', boardId);
      throw error;
    }
  },
  createCard: async ({ dispatch }, { boardId, ...card }) => {
    await KanbanAPI.createCard(boardId, card);
    await dispatch('fetchBoard', boardId);
  },
  updateCard: async ({ dispatch }, { boardId, id, ...card }) => {
    await KanbanAPI.updateCard(boardId, id, card);
    await dispatch('fetchBoard', boardId);
  },
  deleteCard: async ({ dispatch }, { boardId, id }) => {
    await KanbanAPI.deleteCard(boardId, id);
    await dispatch('fetchBoard', boardId);
  },
  createColumn: async ({ dispatch }, { boardId, ...column }) => {
    await KanbanAPI.createColumn(boardId, column);
    await dispatch('fetchBoard', boardId);
  },
  updateColumn: async ({ dispatch }, { boardId, id, ...column }) => {
    await KanbanAPI.updateColumn(boardId, id, column);
    await dispatch('fetchBoard', boardId);
  },
  deleteColumn: async ({ dispatch }, { boardId, id }) => {
    await KanbanAPI.deleteColumn(boardId, id);
    await dispatch('fetchBoard', boardId);
  },
  createLabel: async ({ dispatch }, { boardId, ...label }) => {
    await KanbanAPI.createLabel(boardId, label);
    await dispatch('fetchBoard', boardId);
  },
  updateLabel: async ({ dispatch }, { boardId, id, ...label }) => {
    await KanbanAPI.updateLabel(boardId, id, label);
    await dispatch('fetchBoard', boardId);
  },
  deleteLabel: async ({ dispatch }, { boardId, id }) => {
    await KanbanAPI.deleteLabel(boardId, id);
    await dispatch('fetchBoard', boardId);
  },
  createComment: async ({ dispatch }, { boardId, cardId, content }) => {
    await KanbanAPI.createComment(boardId, cardId, content);
    await dispatch('fetchBoard', boardId);
  },
  updateComment: async ({ dispatch }, { boardId, cardId, id, content }) => {
    await KanbanAPI.updateComment(boardId, cardId, id, content);
    await dispatch('fetchBoard', boardId);
  },
  deleteComment: async ({ dispatch }, { boardId, cardId, id }) => {
    await KanbanAPI.deleteComment(boardId, cardId, id);
    await dispatch('fetchBoard', boardId);
  },
  addAttachment: async ({ dispatch }, { boardId, cardId, file }) => {
    await KanbanAPI.addAttachment(boardId, cardId, file);
    await dispatch('fetchBoard', boardId);
  },
  removeAttachment: async ({ dispatch }, { boardId, cardId, id }) => {
    await KanbanAPI.removeAttachment(boardId, cardId, id);
    await dispatch('fetchBoard', boardId);
  },
  // Real-time: refetch only when the event targets the board we are viewing.
  onBoardUpdated: ({ state: s, dispatch }, boardId) => {
    if (s.currentBoard && s.currentBoard.id === boardId)
      dispatch('fetchBoard', boardId);
  },
};

export const mutations = {
  [types.SET_KANBAN_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_KANBAN_BOARDS](_state, data) {
    _state.boards = data;
  },
  [types.ADD_KANBAN_BOARD](_state, data) {
    _state.boards.push(data);
  },
  [types.DELETE_KANBAN_BOARD](_state, id) {
    _state.boards = _state.boards.filter(b => b.id !== id);
  },
  [types.SET_KANBAN_CURRENT_BOARD](_state, data) {
    _state.currentBoard = data;
  },
};

export default { namespaced: true, state, getters, actions, mutations };
