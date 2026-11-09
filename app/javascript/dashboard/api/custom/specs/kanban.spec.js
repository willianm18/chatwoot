import kanbanAPI from '../kanban';

describe('KanbanBoardsAPI', () => {
  it('is account scoped on custom/kanban/boards', () => {
    expect(kanbanAPI.url).toContain('custom/kanban/boards');
  });

  it('builds nested resource paths', () => {
    expect(kanbanAPI.nested(7, 'cards')).toContain(
      'custom/kanban/boards/7/cards'
    );
  });
});
