/* global axios */
import ApiClient from '../ApiClient';

// [fazer.ai fork] Native team-tasks Kanban API client.
class KanbanBoardsAPI extends ApiClient {
  constructor() {
    super('custom/kanban/boards', { accountScoped: true });
  }

  nested(boardId, resource) {
    return `${this.url}/${boardId}/${resource}`;
  }

  // Columns
  createColumn(boardId, data) {
    return axios.post(this.nested(boardId, 'columns'), { column: data });
  }

  updateColumn(boardId, id, data) {
    return axios.patch(`${this.nested(boardId, 'columns')}/${id}`, {
      column: data,
    });
  }

  deleteColumn(boardId, id) {
    return axios.delete(`${this.nested(boardId, 'columns')}/${id}`);
  }

  reorderColumns(boardId, columnIds) {
    return axios.patch(`${this.nested(boardId, 'columns')}/reorder`, {
      column_ids: columnIds,
    });
  }

  // Cards
  createCard(boardId, data) {
    return axios.post(this.nested(boardId, 'cards'), { card: data });
  }

  updateCard(boardId, id, data) {
    return axios.patch(`${this.nested(boardId, 'cards')}/${id}`, {
      card: data,
    });
  }

  deleteCard(boardId, id) {
    return axios.delete(`${this.nested(boardId, 'cards')}/${id}`);
  }

  moveCard(boardId, id, { columnId, position }) {
    return axios.patch(`${this.nested(boardId, 'cards')}/${id}/move`, {
      column_id: columnId,
      position,
    });
  }

  // Labels
  createLabel(boardId, data) {
    return axios.post(this.nested(boardId, 'labels'), { label: data });
  }

  deleteLabel(boardId, id) {
    return axios.delete(`${this.nested(boardId, 'labels')}/${id}`);
  }

  // Members
  getMembers(boardId) {
    return axios.get(this.nested(boardId, 'members'));
  }

  addMember(boardId, userId) {
    return axios.post(this.nested(boardId, 'members'), { user_id: userId });
  }

  removeMember(boardId, memberId) {
    return axios.delete(`${this.nested(boardId, 'members')}/${memberId}`);
  }
}

export default new KanbanBoardsAPI();
