import { frontendURL } from '../../../helper/URLHelper';
import KanbanIndex from './Index.vue';
import BoardList from './BoardList.vue';
import BoardView from './BoardView.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    component: KanbanIndex,
    children: [
      { path: '', name: 'kanban_view', component: BoardList, meta },
      {
        path: ':boardId',
        name: 'kanban_board',
        component: BoardView,
        meta,
        props: true,
      },
    ],
  },
];
