# Kanban (Team Tasks) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native Trello-style Kanban for day-to-day team tasks inside this Chatwoot fork, reusing the existing `kanban_view` route and sidebar icon (which today only shows a Pro paywall).

**Architecture:** New Rails models/controllers under a `custom_kanban_*` table prefix and `Custom::Kanban::` namespace, account-scoped REST API nested in `config/routes.rb`, serialized with jbuilder. Vue 3 (`<script setup>`) frontend under `routes/dashboard/kanban/` with a Vuex module and `ApiClient`-based clients, drag-and-drop via the already-present `vuedraggable`. No real-time in V1 (board reflects changes on reload).

**Tech Stack:** Rails 7 / ActiveRecord, RSpec, Vue 3 Composition API, Vuex, vuedraggable, Tailwind (design-system `n-*` tokens), vue-i18n.

## Global Constraints

- New code lives in NEW files under `custom` namespaces; edits to upstream files are minimal and must be logged in `.claude/CLAUDE.md` → "Mudanças nossas". (Files to edit: `routes/dashboard/kanban/Index.vue`, maybe `kanban.routes.js`, `config/routes.rb`.)
- Migrations: create with `bundle exec rails g migration <Name>` (real timestamp), and make them idempotent (`unless table_exists?` / `unless column_exists?`). No hand-rounded versions.
- No raw SQL / `execute` / SQL heredocs — ActiveRecord only (`where`, `find_each`, `update!`).
- Prefer Rails associations + `dependent: :destroy` over DB foreign-key constraints.
- i18n: fork strings go in `app/javascript/dashboard/i18n/fazer-ai/locale/<locale>/kanban.json` for **en, pt_BR and es** — every key present in all three. Never touch upstream locale trees.
- Styling: Tailwind utility classes only — no custom/scoped CSS, no inline styles. Use `n-*` design tokens.
- Vue: Composition API with `<script setup>`; components PascalCase; events camelCase; PropTypes/`defineProps` typed; no bare strings (use i18n).
- RuboCop: 150-char max line. Compact `module/class` definitions.
- Each feature needs specs covering main flows + critical edge cases; avoid specs that only restate the implementation.
- Permission model (V1): a user may access a board if they are a board **member** OR an account **administrator**. The **creator (owner)** is always a member and is the only one who can manage membership or delete the board. Access-denied board lookups return **404**; owner-only actions attempted by a non-owner member return **403**; invalid params return **422**.
- Brand is always `fazer.ai` (lowercase, dot) in prose/copy.
- Commits: Conventional Commits, no reference to Claude in the message body. Work happens on branch `feat/kanban-team-tasks`.

---

## File Structure

**Backend (new):**
- `db/migrate/*_create_custom_kanban_boards.rb` (+ board_members, columns, cards, labels, card_labels — one migration each)
- `app/models/custom/kanban/board.rb`
- `app/models/custom/kanban/board_member.rb`
- `app/models/custom/kanban/column.rb`
- `app/models/custom/kanban/card.rb`
- `app/models/custom/kanban/label.rb`
- `app/models/custom/kanban/card_label.rb`
- `app/controllers/api/v1/accounts/custom/kanban/base_controller.rb`
- `app/controllers/api/v1/accounts/custom/kanban/boards_controller.rb`
- `app/controllers/api/v1/accounts/custom/kanban/members_controller.rb`
- `app/controllers/api/v1/accounts/custom/kanban/columns_controller.rb`
- `app/controllers/api/v1/accounts/custom/kanban/cards_controller.rb`
- `app/controllers/api/v1/accounts/custom/kanban/labels_controller.rb`
- `app/views/api/v1/accounts/custom/kanban/boards/{index,show,create,update}.json.jbuilder` + `_board.json.jbuilder`, `_column.json.jbuilder`, `_card.json.jbuilder`, `_label.json.jbuilder`

**Backend (edit, logged as upstream change):**
- `config/routes.rb` — nested resources under a `custom` scope.

**Frontend (new):**
- `app/javascript/dashboard/api/custom/kanban.js` (board/column/card/label/member clients)
- `app/javascript/dashboard/store/modules/custom/kanban.js`
- `app/javascript/dashboard/routes/dashboard/kanban/BoardList.vue` (board list; rendered by Index.vue)
- `app/javascript/dashboard/routes/dashboard/kanban/BoardView.vue`
- `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanColumn.vue`
- `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanCard.vue`
- `app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue`
- `app/javascript/dashboard/routes/dashboard/kanban/components/BoardMembersDialog.vue`
- `app/javascript/dashboard/routes/dashboard/kanban/constants.js` (label color palette)

**Frontend (edit, logged as upstream change):**
- `app/javascript/dashboard/routes/dashboard/kanban/Index.vue` — paywall → router-style host for BoardList/BoardView.
- `app/javascript/dashboard/routes/dashboard/kanban/kanban.routes.js` — add `:boardId` child route.
- `app/javascript/dashboard/store/index.js` — register the `kanban` module.
- `app/javascript/dashboard/store/mutation-types.js` — add `KANBAN_*` types.

**i18n (edit our own overlay):**
- `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/kanban.json`

---

## Task 1: Board + BoardMember models and migrations

**Files:**
- Create: `db/migrate/*_create_custom_kanban_boards.rb`, `db/migrate/*_create_custom_kanban_board_members.rb`
- Create: `app/models/custom/kanban/board.rb`, `app/models/custom/kanban/board_member.rb`
- Test: `spec/models/custom/kanban/board_spec.rb`

**Interfaces:**
- Produces: `Custom::Kanban::Board` with `belongs_to :account`, `has_many :members`, `has_many :member_users`, `scope .accessible_by(user)`, `#owned_by?(user)`. `Custom::Kanban::BoardMember` with `belongs_to :board`, `belongs_to :user`.

- [ ] **Step 1: Generate the migrations**

Run:
```bash
bundle exec rails g migration CreateCustomKanbanBoards
bundle exec rails g migration CreateCustomKanbanBoardMembers
```

- [ ] **Step 2: Write the boards migration** (`db/migrate/*_create_custom_kanban_boards.rb`)

```ruby
class CreateCustomKanbanBoards < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:custom_kanban_boards)

    create_table :custom_kanban_boards do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.bigint :created_by_id
      t.timestamps
    end
    add_index :custom_kanban_boards, :account_id
  end
end
```

- [ ] **Step 3: Write the board_members migration** (`db/migrate/*_create_custom_kanban_board_members.rb`)

```ruby
class CreateCustomKanbanBoardMembers < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:custom_kanban_board_members)

    create_table :custom_kanban_board_members do |t|
      t.bigint :custom_kanban_board_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :custom_kanban_board_members,
              %i[custom_kanban_board_id user_id],
              unique: true, name: 'idx_custom_kanban_board_members_on_board_and_user'
  end
end
```

- [ ] **Step 4: Run the migrations**

Run: `bundle exec rails db:migrate`
Expected: both tables created; `db/schema.rb` updated.

- [ ] **Step 5: Write the BoardMember model** (`app/models/custom/kanban/board_member.rb`)

```ruby
class Custom::Kanban::BoardMember < ApplicationRecord
  self.table_name = 'custom_kanban_board_members'

  belongs_to :board, class_name: 'Custom::Kanban::Board', foreign_key: :custom_kanban_board_id, inverse_of: :members
  belongs_to :user

  validates :user_id, uniqueness: { scope: :custom_kanban_board_id }
end
```

- [ ] **Step 6: Write the failing Board spec** (`spec/models/custom/kanban/board_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe Custom::Kanban::Board do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  def build_board(creator)
    board = described_class.create!(account: account, name: 'Fiscal', created_by_id: creator.id)
    board.members.create!(user: creator)
    board
  end

  describe '.accessible_by' do
    it 'includes boards the user is a member of' do
      board = build_board(owner)
      board.members.create!(user: member)
      expect(described_class.accessible_by(member)).to include(board)
    end

    it 'excludes boards the user is not a member of' do
      board = build_board(owner)
      expect(described_class.accessible_by(outsider)).not_to include(board)
    end

    it 'includes every account board for an administrator' do
      board = build_board(owner)
      expect(described_class.accessible_by(admin)).to include(board)
    end
  end

  describe '#owned_by?' do
    it 'is true only for the creator' do
      board = build_board(owner)
      expect(board.owned_by?(owner)).to be(true)
      expect(board.owned_by?(member)).to be(false)
    end
  end
end
```

- [ ] **Step 7: Run it to confirm it fails**

Run: `bundle exec rspec spec/models/custom/kanban/board_spec.rb`
Expected: FAIL — `uninitialized constant Custom::Kanban::Board`.

- [ ] **Step 8: Write the Board model** (`app/models/custom/kanban/board.rb`)

```ruby
class Custom::Kanban::Board < ApplicationRecord
  self.table_name = 'custom_kanban_boards'

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :members, class_name: 'Custom::Kanban::BoardMember',
                     foreign_key: :custom_kanban_board_id, inverse_of: :board, dependent: :destroy
  has_many :member_users, through: :members, source: :user

  validates :name, presence: true

  # A user can access a board when they are a member of it, or when they are an
  # administrator of the account (admins see every board — see design spec §2).
  scope :accessible_by, lambda { |user|
    account_boards = where(account_id: user.account_ids)
    return account_boards if user.administrator?

    account_boards
      .joins(:members)
      .where(custom_kanban_board_members: { user_id: user.id })
      .distinct
  }

  def owned_by?(user)
    created_by_id == user.id
  end
end
```

Note: `user.administrator?` / `user.account_ids` — confirm the helper names on `User`/`AccountUser`; if `administrator?` is account-scoped, use `user.administrator?(account)` with the board's account. Adjust the scope to the actual API (the admin check may need `AccountUser.where(account_id:, user_id:, role: :administrator)`).

- [ ] **Step 9: Run the spec to confirm it passes**

Run: `bundle exec rspec spec/models/custom/kanban/board_spec.rb`
Expected: PASS (4 examples).

- [ ] **Step 10: Commit**

```bash
git add db/migrate app/models/custom/kanban/board.rb app/models/custom/kanban/board_member.rb db/schema.rb spec/models/custom/kanban/board_spec.rb
git commit -m "feat(kanban): board and board-member models with access scope"
```

---

## Task 2: Column + Card models and migrations

**Files:**
- Create: `db/migrate/*_create_custom_kanban_columns.rb`, `db/migrate/*_create_custom_kanban_cards.rb`
- Create: `app/models/custom/kanban/column.rb`, `app/models/custom/kanban/card.rb`
- Modify: `app/models/custom/kanban/board.rb` (add `has_many :columns`, `default_columns!`)
- Test: `spec/models/custom/kanban/card_spec.rb`

**Interfaces:**
- Consumes: `Custom::Kanban::Board` (Task 1).
- Produces: `Custom::Kanban::Column` (`belongs_to :board`, `has_many :cards`, ordered by `position`), `Custom::Kanban::Card` (`belongs_to :column`, `belongs_to :assignee` optional, `position`, `due_date`). `Board#default_columns!` creates "To do / Doing / Done".

- [ ] **Step 1: Generate + write the columns migration**

Run: `bundle exec rails g migration CreateCustomKanbanColumns`

```ruby
class CreateCustomKanbanColumns < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:custom_kanban_columns)

    create_table :custom_kanban_columns do |t|
      t.bigint :custom_kanban_board_id, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :custom_kanban_columns, :custom_kanban_board_id
  end
end
```

- [ ] **Step 2: Generate + write the cards migration**

Run: `bundle exec rails g migration CreateCustomKanbanCards`

```ruby
class CreateCustomKanbanCards < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:custom_kanban_cards)

    create_table :custom_kanban_cards do |t|
      t.bigint :custom_kanban_column_id, null: false
      t.string :title, null: false
      t.text :description
      t.bigint :assignee_id
      t.date :due_date
      t.integer :position, null: false, default: 0
      t.bigint :created_by_id
      t.timestamps
    end
    add_index :custom_kanban_cards, :custom_kanban_column_id
  end
end
```

- [ ] **Step 3: Run migrations**

Run: `bundle exec rails db:migrate`
Expected: tables created; schema updated.

- [ ] **Step 4: Write the Column model** (`app/models/custom/kanban/column.rb`)

```ruby
class Custom::Kanban::Column < ApplicationRecord
  self.table_name = 'custom_kanban_columns'

  belongs_to :board, class_name: 'Custom::Kanban::Board', foreign_key: :custom_kanban_board_id, inverse_of: :columns
  has_many :cards, class_name: 'Custom::Kanban::Card',
                   foreign_key: :custom_kanban_column_id, inverse_of: :column, dependent: :destroy

  validates :name, presence: true

  default_scope { order(:position, :id) }
end
```

- [ ] **Step 5: Write the Card model** (`app/models/custom/kanban/card.rb`)

```ruby
class Custom::Kanban::Card < ApplicationRecord
  self.table_name = 'custom_kanban_cards'

  belongs_to :column, class_name: 'Custom::Kanban::Column', foreign_key: :custom_kanban_column_id, inverse_of: :cards
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :title, presence: true

  default_scope { order(:position, :id) }

  delegate :board, to: :column
end
```

- [ ] **Step 6: Extend the Board model** (`app/models/custom/kanban/board.rb`) — add inside the class:

```ruby
  has_many :columns, class_name: 'Custom::Kanban::Column',
                     foreign_key: :custom_kanban_board_id, inverse_of: :board, dependent: :destroy

  DEFAULT_COLUMN_KEYS = %w[to_do doing done].freeze

  # Seed the three starter columns on a brand new board (editable afterwards).
  def default_columns!
    DEFAULT_COLUMN_KEYS.each_with_index do |key, index|
      columns.create!(name: I18n.t("kanban.default_columns.#{key}", default: key.humanize), position: index)
    end
  end
```

Note: backend copy for the default column names goes in `config/locales/fazer_ai.<locale>.yml` under `kanban.default_columns.*` (en, pt_BR, es). If you prefer not to add a backend locale, pass literal names from the controller instead and drop the `I18n.t`.

- [ ] **Step 7: Write the failing Card spec** (`spec/models/custom/kanban/card_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe Custom::Kanban::Card do
  let(:account) { create(:account) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'Fiscal') }
  let(:column) { board.columns.create!(name: 'To do', position: 0) }

  it 'requires a title' do
    card = described_class.new(column: column)
    expect(card).not_to be_valid
    expect(card.errors[:title]).to be_present
  end

  it 'orders cards by position' do
    c2 = column.cards.create!(title: 'second', position: 1)
    c1 = column.cards.create!(title: 'first', position: 0)
    expect(column.cards.to_a).to eq([c1, c2])
  end

  it 'reaches the board through its column' do
    card = column.cards.create!(title: 'x', position: 0)
    expect(card.board).to eq(board)
  end
end
```

- [ ] **Step 8: Run it**

Run: `bundle exec rspec spec/models/custom/kanban/card_spec.rb`
Expected: PASS (3 examples).

- [ ] **Step 9: Commit**

```bash
git add db/migrate app/models/custom/kanban/column.rb app/models/custom/kanban/card.rb app/models/custom/kanban/board.rb db/schema.rb spec/models/custom/kanban/card_spec.rb
git commit -m "feat(kanban): column and card models with ordering and default columns"
```

---

## Task 3: Label + CardLabel models and migrations

**Files:**
- Create: `db/migrate/*_create_custom_kanban_labels.rb`, `db/migrate/*_create_custom_kanban_card_labels.rb`
- Create: `app/models/custom/kanban/label.rb`, `app/models/custom/kanban/card_label.rb`
- Modify: `app/models/custom/kanban/board.rb` (`has_many :labels`), `app/models/custom/kanban/card.rb` (`has_many :labels` through)
- Test: `spec/models/custom/kanban/label_spec.rb`

**Interfaces:**
- Produces: `Custom::Kanban::Label` (`belongs_to :board`, `name`, `color`), join `Custom::Kanban::CardLabel`. `Card#labels` (through). `Card#label_ids=` usable for assignment.

- [ ] **Step 1: Generate + write the labels migration**

Run: `bundle exec rails g migration CreateCustomKanbanLabels`

```ruby
class CreateCustomKanbanLabels < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:custom_kanban_labels)

    create_table :custom_kanban_labels do |t|
      t.bigint :custom_kanban_board_id, null: false
      t.string :name, null: false
      t.string :color, null: false
      t.timestamps
    end
    add_index :custom_kanban_labels, :custom_kanban_board_id
  end
end
```

- [ ] **Step 2: Generate + write the card_labels migration**

Run: `bundle exec rails g migration CreateCustomKanbanCardLabels`

```ruby
class CreateCustomKanbanCardLabels < ActiveRecord::Migration[7.1]
  def change
    return if table_exists?(:custom_kanban_card_labels)

    create_table :custom_kanban_card_labels do |t|
      t.bigint :custom_kanban_card_id, null: false
      t.bigint :custom_kanban_label_id, null: false
      t.timestamps
    end
    add_index :custom_kanban_card_labels,
              %i[custom_kanban_card_id custom_kanban_label_id],
              unique: true, name: 'idx_custom_kanban_card_labels_on_card_and_label'
  end
end
```

- [ ] **Step 3: Run migrations** — `bundle exec rails db:migrate`

- [ ] **Step 4: Write the models**

`app/models/custom/kanban/card_label.rb`:
```ruby
class Custom::Kanban::CardLabel < ApplicationRecord
  self.table_name = 'custom_kanban_card_labels'

  belongs_to :card, class_name: 'Custom::Kanban::Card', foreign_key: :custom_kanban_card_id, inverse_of: :card_labels
  belongs_to :label, class_name: 'Custom::Kanban::Label', foreign_key: :custom_kanban_label_id, inverse_of: :card_labels

  validates :custom_kanban_label_id, uniqueness: { scope: :custom_kanban_card_id }
end
```

`app/models/custom/kanban/label.rb`:
```ruby
class Custom::Kanban::Label < ApplicationRecord
  self.table_name = 'custom_kanban_labels'

  # Keep in sync with the frontend palette in routes/dashboard/kanban/constants.js.
  PALETTE = %w[
    #9F1239 #B91C1C #B45309 #15803D #0F766E
    #0E7490 #1D4ED8 #4338CA #6D28D9 #BE185D
  ].freeze

  belongs_to :board, class_name: 'Custom::Kanban::Board', foreign_key: :custom_kanban_board_id, inverse_of: :labels
  has_many :card_labels, class_name: 'Custom::Kanban::CardLabel',
                         foreign_key: :custom_kanban_label_id, inverse_of: :label, dependent: :destroy

  validates :name, presence: true
  validates :color, inclusion: { in: PALETTE }
end
```

- [ ] **Step 5: Wire associations into Board and Card**

In `app/models/custom/kanban/board.rb` add:
```ruby
  has_many :labels, class_name: 'Custom::Kanban::Label',
                    foreign_key: :custom_kanban_board_id, inverse_of: :board, dependent: :destroy
```

In `app/models/custom/kanban/card.rb` add:
```ruby
  has_many :card_labels, class_name: 'Custom::Kanban::CardLabel',
                         foreign_key: :custom_kanban_card_id, inverse_of: :card, dependent: :destroy
  has_many :labels, through: :card_labels
```

- [ ] **Step 6: Write the Label spec** (`spec/models/custom/kanban/label_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe Custom::Kanban::Label do
  let(:account) { create(:account) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'Fiscal') }

  it 'rejects a color outside the palette' do
    label = board.labels.new(name: 'Urgent', color: '#123456')
    expect(label).not_to be_valid
  end

  it 'attaches to a card through card_labels' do
    label = board.labels.create!(name: 'Urgent', color: described_class::PALETTE.first)
    column = board.columns.create!(name: 'To do', position: 0)
    card = column.cards.create!(title: 'x', position: 0)
    card.labels << label
    expect(card.reload.labels).to include(label)
  end
end
```

- [ ] **Step 7: Run it** — `bundle exec rspec spec/models/custom/kanban/label_spec.rb` — Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add db/migrate app/models/custom/kanban/label.rb app/models/custom/kanban/card_label.rb app/models/custom/kanban/board.rb app/models/custom/kanban/card.rb db/schema.rb spec/models/custom/kanban/label_spec.rb
git commit -m "feat(kanban): per-board labels with palette validation"
```

---

## Task 4: Routes, base controller, Boards controller + jbuilder

**Files:**
- Modify: `config/routes.rb` (log in "Mudanças nossas")
- Create: `app/controllers/api/v1/accounts/custom/kanban/base_controller.rb`
- Create: `app/controllers/api/v1/accounts/custom/kanban/boards_controller.rb`
- Create: `app/views/api/v1/accounts/custom/kanban/boards/{index,show,create,update}.json.jbuilder`, `_board.json.jbuilder`, `_column.json.jbuilder`, `_card.json.jbuilder`, `_label.json.jbuilder`
- Test: `spec/controllers/api/v1/accounts/custom/kanban/boards_controller_spec.rb`

**Interfaces:**
- Consumes: models from Tasks 1–3.
- Produces: `GET/POST/GET/PATCH/DELETE /api/v1/accounts/:account_id/custom/kanban/boards[/:id]`. `show` embeds `columns → cards (+ label ids)` and `labels`. Base controller exposes `current_board` (scoped by `accessible_by`) and `authorize_owner!`.

- [ ] **Step 1: Add the routes** — in `config/routes.rb`, inside the account `namespace :accounts` member block (near `resources :macros`), add:

```ruby
          # [fazer.ai fork] Native team-tasks Kanban (see docs/superpowers/specs/2026-11-09-kanban-team-tasks-design.md)
          namespace :custom do
            namespace :kanban do
              resources :boards, only: [:index, :show, :create, :update, :destroy] do
                resources :members, only: [:index, :create, :destroy]
                resources :labels, only: [:create, :update, :destroy]
                resources :columns, only: [:create, :update, :destroy] do
                  collection { patch :reorder }
                end
                resources :cards, only: [:create, :update, :destroy] do
                  member { patch :move }
                end
              end
            end
          end
```

- [ ] **Step 2: Write the base controller** (`app/controllers/api/v1/accounts/custom/kanban/base_controller.rb`)

```ruby
class Api::V1::Accounts::Custom::Kanban::BaseController < Api::V1::Accounts::BaseController
  before_action :current_board

  private

  def current_board
    @current_board ||= Custom::Kanban::Board.accessible_by(current_user).find_by(
      id: params[:board_id] || params[:id], account_id: Current.account.id
    )
    raise ActiveRecord::RecordNotFound if @current_board.nil?
  end

  def authorize_owner!
    render_unauthorized('You are not the owner of this board') unless @current_board.owned_by?(current_user)
  end
end
```

Note: confirm `render_unauthorized` exists on the base controller chain; if not, `render json: { error: ... }, status: :forbidden`.

- [ ] **Step 3: Write the Boards controller** (`app/controllers/api/v1/accounts/custom/kanban/boards_controller.rb`)

```ruby
class Api::V1::Accounts::Custom::Kanban::BoardsController < Api::V1::Accounts::BaseController
  before_action :set_board, only: [:show, :update, :destroy]
  before_action :authorize_owner!, only: [:destroy]

  def index
    @boards = Custom::Kanban::Board.accessible_by(current_user)
                                   .where(account_id: Current.account.id).order(:name)
  end

  def show; end

  def create
    @board = Current.account.kanban_boards.new(board_params.merge(created_by_id: current_user.id))
    @board.save!
    @board.members.create!(user: current_user)
    @board.default_columns!
    render :show
  end

  def update
    @board.update!(board_params)
    render :show
  end

  def destroy
    @board.destroy!
    head :ok
  end

  private

  def set_board
    @board = Custom::Kanban::Board.accessible_by(current_user)
                                  .find_by!(id: params[:id], account_id: Current.account.id)
  end

  def authorize_owner!
    render json: { error: 'Only the board owner can perform this action' }, status: :forbidden unless @board.owned_by?(current_user)
  end

  def board_params
    params.require(:board).permit(:name)
  end
end
```

Note: add `has_many :kanban_boards, class_name: 'Custom::Kanban::Board', dependent: :destroy` to `app/models/account.rb`. Account is an upstream file — prefer a concern `app/models/concerns/custom/account_kanban.rb` with `included { has_many :kanban_boards, ... }` and `include Custom::AccountKanban` (one-line upstream edit, logged), mirroring the existing `Custom::InboxCustomColor` pattern.

- [ ] **Step 4: Write the jbuilder partials**

`_board.json.jbuilder`:
```ruby
json.id board.id
json.name board.name
json.created_by_id board.created_by_id
json.owner board.owned_by?(current_user)
```

`_column.json.jbuilder`:
```ruby
json.id column.id
json.name column.name
json.position column.position
```

`_card.json.jbuilder`:
```ruby
json.id card.id
json.column_id card.custom_kanban_column_id
json.title card.title
json.description card.description
json.assignee_id card.assignee_id
json.due_date card.due_date
json.position card.position
json.label_ids card.labels.map(&:id)
```

`_label.json.jbuilder`:
```ruby
json.id label.id
json.name label.name
json.color label.color
```

`index.json.jbuilder`:
```ruby
json.payload do
  json.array! @boards, partial: 'api/v1/accounts/custom/kanban/boards/board', as: :board
end
```

`show.json.jbuilder`:
```ruby
json.partial! 'api/v1/accounts/custom/kanban/boards/board', board: @board
json.columns @board.columns.includes(cards: :labels) do |column|
  json.partial! 'api/v1/accounts/custom/kanban/boards/column', column: column
  json.cards column.cards do |card|
    json.partial! 'api/v1/accounts/custom/kanban/boards/card', card: card
  end
end
json.labels @board.labels.order(:name) do |label|
  json.partial! 'api/v1/accounts/custom/kanban/boards/label', label: label
end
```

`create.json.jbuilder` and `update.json.jbuilder`:
```ruby
json.partial! 'show'
```

- [ ] **Step 5: Write the failing controller spec** (`spec/controllers/api/v1/accounts/custom/kanban/boards_controller_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe 'Kanban boards API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  def create_board(creator)
    board = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: creator.id)
    board.members.create!(user: creator)
    board
  end

  describe 'POST /api/v1/accounts/:account_id/custom/kanban/boards' do
    it 'creates a board, adds the creator as member and seeds columns' do
      expect do
        post "/api/v1/accounts/#{account.id}/custom/kanban/boards",
             params: { board: { name: 'Contábil' } }, headers: owner.create_new_auth_token, as: :json
      end.to change(Custom::Kanban::Board, :count).by(1)
      expect(response).to have_http_status(:success)
      board = Custom::Kanban::Board.last
      expect(board.member_users).to include(owner)
      expect(board.columns.count).to eq(3)
    end
  end

  describe 'GET /api/v1/accounts/:account_id/custom/kanban/boards' do
    it 'lists only boards the user can access' do
      mine = create_board(owner)
      create_board(outsider)
      get "/api/v1/accounts/#{account.id}/custom/kanban/boards", headers: owner.create_new_auth_token, as: :json
      ids = response.parsed_body['payload'].map { |b| b['id'] }
      expect(ids).to contain_exactly(mine.id)
    end

    it 'lists every board for an administrator' do
      a = create_board(owner)
      b = create_board(outsider)
      get "/api/v1/accounts/#{account.id}/custom/kanban/boards", headers: admin.create_new_auth_token, as: :json
      ids = response.parsed_body['payload'].map { |x| x['id'] }
      expect(ids).to include(a.id, b.id)
    end
  end

  describe 'GET show' do
    it 'returns 404 for a board the user cannot access' do
      board = create_board(outsider)
      get "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}", headers: owner.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE destroy' do
    it 'forbids a non-owner member from deleting' do
      board = create_board(owner)
      board.members.create!(user: outsider)
      delete "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}", headers: outsider.create_new_auth_token, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

- [ ] **Step 6: Run it** — `bundle exec rspec spec/controllers/api/v1/accounts/custom/kanban/boards_controller_spec.rb` — Expected: PASS (5 examples).

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/accounts/custom app/views/api/v1/accounts/custom app/models/concerns/custom/account_kanban.rb app/models/account.rb spec/controllers/api/v1/accounts/custom
git commit -m "feat(kanban): boards API with access scoping and owner-only delete"
```

---

## Task 5: Columns controller (create/update/destroy/reorder)

**Files:**
- Create: `app/controllers/api/v1/accounts/custom/kanban/columns_controller.rb`
- Create: `app/views/api/v1/accounts/custom/kanban/columns/show.json.jbuilder`
- Test: `spec/controllers/api/v1/accounts/custom/kanban/columns_controller_spec.rb`

**Interfaces:**
- Consumes: `current_board` (base controller, Task 4).
- Produces: `POST/PATCH/DELETE .../boards/:board_id/columns[/:id]` and `PATCH .../columns/reorder` with `{ column_ids: [...] }` rewriting `position` by index.

- [ ] **Step 1: Write the controller** (`app/controllers/api/v1/accounts/custom/kanban/columns_controller.rb`)

```ruby
class Api::V1::Accounts::Custom::Kanban::ColumnsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_column, only: [:update, :destroy]

  def create
    @column = @current_board.columns.create!(column_params.merge(position: @current_board.columns.count))
    render :show
  end

  def update
    @column.update!(column_params)
    render :show
  end

  def destroy
    @column.destroy!
    head :ok
  end

  def reorder
    ids = params.require(:column_ids).map(&:to_i)
    @current_board.columns.where(id: ids).find_each do |column|
      column.update!(position: ids.index(column.id))
    end
    head :ok
  end

  private

  def set_column
    @column = @current_board.columns.find(params[:id])
  end

  def column_params
    params.require(:column).permit(:name)
  end
end
```

- [ ] **Step 2: Write the jbuilder** (`.../columns/show.json.jbuilder`)

```ruby
json.partial! 'api/v1/accounts/custom/kanban/boards/column', column: @column
```

- [ ] **Step 3: Write the spec** (`spec/.../columns_controller_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe 'Kanban columns API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b
  end

  it 'creates a column at the end' do
    board.columns.create!(name: 'To do', position: 0)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/columns",
         params: { column: { name: 'Doing' } }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(board.columns.last.position).to eq(1)
  end

  it 'reorders columns by the given id order' do
    c1 = board.columns.create!(name: 'A', position: 0)
    c2 = board.columns.create!(name: 'B', position: 1)
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/columns/reorder",
          params: { column_ids: [c2.id, c1.id] }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(c1.reload.position).to eq(1)
    expect(c2.reload.position).to eq(0)
  end
end
```

- [ ] **Step 4: Run it** — `bundle exec rspec spec/controllers/api/v1/accounts/custom/kanban/columns_controller_spec.rb` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/accounts/custom/kanban/columns_controller.rb app/views/api/v1/accounts/custom/kanban/columns spec/controllers/api/v1/accounts/custom/kanban/columns_controller_spec.rb
git commit -m "feat(kanban): columns controller with reorder"
```

---

## Task 6: Cards controller (create/update/destroy/move)

**Files:**
- Create: `app/controllers/api/v1/accounts/custom/kanban/cards_controller.rb`
- Create: `app/views/api/v1/accounts/custom/kanban/cards/show.json.jbuilder`
- Test: `spec/controllers/api/v1/accounts/custom/kanban/cards_controller_spec.rb`

**Interfaces:**
- Consumes: `current_board` (Task 4).
- Produces: `POST/PATCH/DELETE .../cards[/:id]` and `PATCH .../cards/:id/move` with `{ column_id, position }`. Create/update accept `column_id, title, description, assignee_id, due_date, label_ids: []`.

- [ ] **Step 1: Write the controller** (`app/controllers/api/v1/accounts/custom/kanban/cards_controller.rb`)

```ruby
class Api::V1::Accounts::Custom::Kanban::CardsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_card, only: [:update, :destroy, :move]

  def create
    column = @current_board.columns.find(params.require(:card).require(:column_id))
    @card = column.cards.create!(card_params.merge(position: column.cards.count, created_by_id: current_user.id))
    assign_labels(@card)
    render :show
  end

  def update
    @card.update!(card_params)
    assign_labels(@card) if params[:card].key?(:label_ids)
    render :show
  end

  def destroy
    @card.destroy!
    head :ok
  end

  # Move the card to column_id at position, resequencing the target column.
  def move
    target = @current_board.columns.find(params.require(:column_id))
    position = params.require(:position).to_i
    @card.update!(column: target)
    siblings = target.cards.where.not(id: @card.id).to_a
    siblings.insert(position, @card)
    siblings.each_with_index { |card, index| card.update!(position: index) }
    head :ok
  end

  private

  def set_card
    @card = Custom::Kanban::Card.where(custom_kanban_column_id: @current_board.columns.select(:id)).find(params[:id])
  end

  def assign_labels(card)
    ids = Array(params.dig(:card, :label_ids)).map(&:to_i)
    card.label_ids = @current_board.labels.where(id: ids).pluck(:id)
  end

  def card_params
    params.require(:card).permit(:title, :description, :assignee_id, :due_date)
  end
end
```

Note: validate `assignee_id` belongs to the account — add `validate :assignee_in_account` on the Card model or check in the controller boundary returning 422. Keep it minimal: in `assign`/`card_params`, reject an `assignee_id` not in `Current.account.user_ids` (render 422).

- [ ] **Step 2: Write the jbuilder** (`.../cards/show.json.jbuilder`)

```ruby
json.partial! 'api/v1/accounts/custom/kanban/boards/card', card: @card
```

- [ ] **Step 3: Write the spec** (`spec/.../cards_controller_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe 'Kanban cards API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b
  end
  let!(:todo) { board.columns.create!(name: 'To do', position: 0) }
  let!(:doing) { board.columns.create!(name: 'Doing', position: 1) }

  it 'creates a card at the end of its column' do
    todo.cards.create!(title: 'first', position: 0)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: todo.id, title: 'second' } }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(todo.cards.last.position).to eq(1)
  end

  it 'moves a card to another column and resequences' do
    c = todo.cards.create!(title: 'x', position: 0)
    doing.cards.create!(title: 'a', position: 0)
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{c.id}/move",
          params: { column_id: doing.id, position: 0 }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(c.reload.column).to eq(doing)
    expect(c.reload.position).to eq(0)
    expect(doing.cards.pluck(:position)).to eq([0, 1])
  end

  it 'returns 404 moving a card on a board the user cannot access' do
    other = create(:user, account: account, role: :agent)
    c = todo.cards.create!(title: 'x', position: 0)
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{c.id}/move",
          params: { column_id: doing.id, position: 0 }, headers: other.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
```

- [ ] **Step 4: Run it** — `bundle exec rspec spec/controllers/api/v1/accounts/custom/kanban/cards_controller_spec.rb` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/accounts/custom/kanban/cards_controller.rb app/views/api/v1/accounts/custom/kanban/cards spec/controllers/api/v1/accounts/custom/kanban/cards_controller_spec.rb
git commit -m "feat(kanban): cards controller with move and label assignment"
```

---

## Task 7: Labels + Members controllers

**Files:**
- Create: `app/controllers/api/v1/accounts/custom/kanban/labels_controller.rb`, `.../members_controller.rb`
- Create: `app/views/api/v1/accounts/custom/kanban/labels/show.json.jbuilder`, `.../members/index.json.jbuilder`
- Test: `spec/controllers/api/v1/accounts/custom/kanban/members_controller_spec.rb`

**Interfaces:**
- Consumes: `current_board`, `authorize_owner!` (Task 4).
- Produces: label CRUD (any member); member index/create/destroy (owner only). Member create accepts `user_id`; destroy by `:id` (member id).

- [ ] **Step 1: Write the Labels controller** (`.../labels_controller.rb`)

```ruby
class Api::V1::Accounts::Custom::Kanban::LabelsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_label, only: [:update, :destroy]

  def create
    @label = @current_board.labels.create!(label_params)
    render :show
  end

  def update
    @label.update!(label_params)
    render :show
  end

  def destroy
    @label.destroy!
    head :ok
  end

  private

  def set_label
    @label = @current_board.labels.find(params[:id])
  end

  def label_params
    params.require(:label).permit(:name, :color)
  end
end
```

`.../labels/show.json.jbuilder`:
```ruby
json.partial! 'api/v1/accounts/custom/kanban/boards/label', label: @label
```

- [ ] **Step 2: Write the Members controller** (`.../members_controller.rb`) — owner-only

```ruby
class Api::V1::Accounts::Custom::Kanban::MembersController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :authorize_owner!, only: [:create, :destroy]

  def index
    @members = @current_board.members.includes(:user)
  end

  def create
    user = Current.account.users.find(params.require(:user_id))
    @current_board.members.find_or_create_by!(user: user)
    head :ok
  end

  def destroy
    member = @current_board.members.find(params[:id])
    member.destroy! unless member.user_id == @current_board.created_by_id # owner can't be removed
    head :ok
  end
end
```

`.../members/index.json.jbuilder`:
```ruby
json.payload do
  json.array! @members do |member|
    json.id member.id
    json.user_id member.user_id
    json.name member.user.name
    json.owner member.user_id == @current_board.created_by_id
  end
end
```

- [ ] **Step 3: Write the Members spec** (`spec/.../members_controller_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe 'Kanban members API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let(:stranger) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b
  end

  it 'lets the owner add a member' do
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/members",
         params: { user_id: member.id }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(board.member_users).to include(member)
  end

  it 'forbids a non-owner member from adding members' do
    board.members.create!(user: member)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/members",
         params: { user_id: stranger.id }, headers: member.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end
end
```

- [ ] **Step 4: Run it** — `bundle exec rspec spec/controllers/api/v1/accounts/custom/kanban/members_controller_spec.rb` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/accounts/custom/kanban/labels_controller.rb app/controllers/api/v1/accounts/custom/kanban/members_controller.rb app/views/api/v1/accounts/custom/kanban/labels app/views/api/v1/accounts/custom/kanban/members spec/controllers/api/v1/accounts/custom/kanban/members_controller_spec.rb
git commit -m "feat(kanban): labels and board-membership controllers"
```

---

## Task 8: Frontend API clients

**Files:**
- Create: `app/javascript/dashboard/api/custom/kanban.js`
- Test: `app/javascript/dashboard/api/custom/specs/kanban.spec.js`

**Interfaces:**
- Produces: a default export object `{ boards, columns, cards, labels, members }`. `boards`: `get()`, `show(id)`, `create(data)`, `update(id, data)`, `delete(id)`. `columns.reorder(boardId, columnIds)`, `cards.move(boardId, cardId, { column_id, position })`, nested `create/update/delete(boardId, ...)`.

- [ ] **Step 1: Write the API client** (`app/javascript/dashboard/api/custom/kanban.js`)

```js
/* global axios */
import ApiClient from '../ApiClient';

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
    return axios.patch(`${this.nested(boardId, 'columns')}/${id}`, { column: data });
  }

  deleteColumn(boardId, id) {
    return axios.delete(`${this.nested(boardId, 'columns')}/${id}`);
  }

  reorderColumns(boardId, columnIds) {
    return axios.patch(`${this.nested(boardId, 'columns')}/reorder`, { column_ids: columnIds });
  }

  // Cards
  createCard(boardId, data) {
    return axios.post(this.nested(boardId, 'cards'), { card: data });
  }

  updateCard(boardId, id, data) {
    return axios.patch(`${this.nested(boardId, 'cards')}/${id}`, { card: data });
  }

  deleteCard(boardId, id) {
    return axios.delete(`${this.nested(boardId, 'cards')}/${id}`);
  }

  moveCard(boardId, id, { columnId, position }) {
    return axios.patch(`${this.nested(boardId, 'cards')}/${id}/move`, { column_id: columnId, position });
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
```

- [ ] **Step 2: Write the spec** (`app/javascript/dashboard/api/custom/specs/kanban.spec.js`)

```js
import kanbanAPI from '../kanban';

describe('KanbanBoardsAPI', () => {
  it('is account scoped on custom/kanban/boards', () => {
    expect(kanbanAPI.url).toContain('custom/kanban/boards');
  });
});
```

- [ ] **Step 3: Run it** — `pnpm test app/javascript/dashboard/api/custom/specs/kanban.spec.js` — Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/dashboard/api/custom/kanban.js app/javascript/dashboard/api/custom/specs/kanban.spec.js
git commit -m "feat(kanban): frontend api client"
```

---

## Task 9: Vuex store module

**Files:**
- Create: `app/javascript/dashboard/store/modules/custom/kanban.js`
- Modify: `app/javascript/dashboard/store/index.js` (register), `app/javascript/dashboard/store/mutation-types.js` (add types)
- Test: `app/javascript/dashboard/store/modules/custom/specs/kanban.spec.js`

**Interfaces:**
- Produces: namespaced getters `kanban/getBoards`, `kanban/getCurrentBoard`, `kanban/getUIFlags`; actions `fetchBoards`, `createBoard`, `deleteBoard`, `fetchBoard(id)`, `createCard`, `updateCard`, `moveCard`, `deleteCard`, `createColumn`, `updateColumn`, `deleteColumn`. `moveCard` optimistically updates the local board then calls the API.

- [ ] **Step 1: Add mutation types** — in `store/mutation-types.js`, add inside the exported object:

```js
  SET_KANBAN_UI_FLAG: 'SET_KANBAN_UI_FLAG',
  SET_KANBAN_BOARDS: 'SET_KANBAN_BOARDS',
  ADD_KANBAN_BOARD: 'ADD_KANBAN_BOARD',
  DELETE_KANBAN_BOARD: 'DELETE_KANBAN_BOARD',
  SET_KANBAN_CURRENT_BOARD: 'SET_KANBAN_CURRENT_BOARD',
```

- [ ] **Step 2: Write the store module** (`store/modules/custom/kanban.js`)

```js
import { throwErrorMessage } from 'dashboard/store/utils/api';
import types from '../../mutation-types';
import KanbanAPI from '../../../api/custom/kanban';

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
  moveCard: async ({ state: s, commit, dispatch }, { cardId, toColumnId, position }) => {
    const board = s.currentBoard;
    // Optimistic local move
    let moved;
    board.columns.forEach(col => {
      const idx = col.cards.findIndex(c => c.id === cardId);
      if (idx !== -1) [moved] = col.cards.splice(idx, 1);
    });
    const target = board.columns.find(c => c.id === toColumnId);
    target.cards.splice(position, 0, { ...moved, column_id: toColumnId });
    commit(types.SET_KANBAN_CURRENT_BOARD, { ...board });
    try {
      await KanbanAPI.moveCard(board.id, cardId, { columnId: toColumnId, position });
    } catch (error) {
      await dispatch('fetchBoard', board.id); // reconcile on failure
      throw error;
    }
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
```

Note: actions for `createCard/updateCard/deleteCard/createColumn/...` follow the same shape (call `KanbanAPI.*` then re-`fetchBoard(board.id)` to refresh, since there is no real-time in V1). Add them analogously; keep each wrapped in try/`throwErrorMessage`.

- [ ] **Step 3: Register the module** — in `store/index.js`, import and add under `modules`:

```js
import kanban from './modules/custom/kanban';
// ... inside modules: { ... , kanban }
```

- [ ] **Step 4: Write the store spec** (`store/modules/custom/specs/kanban.spec.js`) — test the optimistic `moveCard` mutation path:

```js
import { mutations } from '../kanban';
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
});
```

- [ ] **Step 5: Run it** — `pnpm test app/javascript/dashboard/store/modules/custom/specs/kanban.spec.js` — Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/store/modules/custom/kanban.js app/javascript/dashboard/store/index.js app/javascript/dashboard/store/mutation-types.js app/javascript/dashboard/store/modules/custom/specs/kanban.spec.js
git commit -m "feat(kanban): vuex store module"
```

---

## Task 10: i18n keys (en, pt_BR, es)

**Files:**
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/kanban.json`

**Interfaces:**
- Produces: `KANBAN.*` keys consumed by all components (Tasks 11–13). Remove the now-unused `KANBAN.PAYWALL.*` block.

- [ ] **Step 1: Replace `en/kanban.json`**

```json
{
  "KANBAN": {
    "HEADER": "Boards",
    "NEW_BOARD": "New board",
    "BOARD_NAME": "Board name",
    "EMPTY_BOARDS": "You have no boards yet. Create your first one.",
    "OWNER": "Owner",
    "MEMBERS": "Members",
    "ADD_MEMBER": "Add member",
    "DELETE_BOARD": "Delete board",
    "NEW_COLUMN": "Add column",
    "COLUMN_NAME": "Column name",
    "NEW_CARD": "Add a card",
    "CARD": {
      "TITLE": "Title",
      "DESCRIPTION": "Description",
      "ASSIGNEE": "Assignee",
      "LABELS": "Labels",
      "DUE_DATE": "Due date",
      "SAVE": "Save",
      "DELETE": "Delete card"
    },
    "FILTERS": {
      "ASSIGNEE": "Filter by assignee",
      "LABEL": "Filter by label",
      "CLEAR": "Clear filters"
    }
  }
}
```

- [ ] **Step 2: Write `pt_BR/kanban.json`** (same keys, Portuguese values)

```json
{
  "KANBAN": {
    "HEADER": "Quadros",
    "NEW_BOARD": "Novo quadro",
    "BOARD_NAME": "Nome do quadro",
    "EMPTY_BOARDS": "Você ainda não tem quadros. Crie o primeiro.",
    "OWNER": "Dono",
    "MEMBERS": "Membros",
    "ADD_MEMBER": "Adicionar membro",
    "DELETE_BOARD": "Excluir quadro",
    "NEW_COLUMN": "Adicionar coluna",
    "COLUMN_NAME": "Nome da coluna",
    "NEW_CARD": "Adicionar cartão",
    "CARD": {
      "TITLE": "Título",
      "DESCRIPTION": "Descrição",
      "ASSIGNEE": "Responsável",
      "LABELS": "Etiquetas",
      "DUE_DATE": "Prazo",
      "SAVE": "Salvar",
      "DELETE": "Excluir cartão"
    },
    "FILTERS": {
      "ASSIGNEE": "Filtrar por responsável",
      "LABEL": "Filtrar por etiqueta",
      "CLEAR": "Limpar filtros"
    }
  }
}
```

- [ ] **Step 3: Write `es/kanban.json`** (same keys, Spanish values)

```json
{
  "KANBAN": {
    "HEADER": "Tableros",
    "NEW_BOARD": "Nuevo tablero",
    "BOARD_NAME": "Nombre del tablero",
    "EMPTY_BOARDS": "Aún no tienes tableros. Crea el primero.",
    "OWNER": "Propietario",
    "MEMBERS": "Miembros",
    "ADD_MEMBER": "Agregar miembro",
    "DELETE_BOARD": "Eliminar tablero",
    "NEW_COLUMN": "Agregar columna",
    "COLUMN_NAME": "Nombre de la columna",
    "NEW_CARD": "Agregar tarjeta",
    "CARD": {
      "TITLE": "Título",
      "DESCRIPTION": "Descripción",
      "ASSIGNEE": "Responsable",
      "LABELS": "Etiquetas",
      "DUE_DATE": "Fecha límite",
      "SAVE": "Guardar",
      "DELETE": "Eliminar tarjeta"
    },
    "FILTERS": {
      "ASSIGNEE": "Filtrar por responsable",
      "LABEL": "Filtrar por etiqueta",
      "CLEAR": "Limpiar filtros"
    }
  }
}
```

- [ ] **Step 4: Run the i18n check** — `ruby scripts/i18n/fork_translations.rb check` — Expected: PASS (every KANBAN key present in en/pt_BR/es).

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale/en/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/es/kanban.json
git commit -m "feat(kanban): i18n keys for board UI (en, pt_BR, es)"
```

---

## Task 11: Board list (replace paywall) + route

**Files:**
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/Index.vue` (paywall → host) — log in "Mudanças nossas"
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/kanban.routes.js` — add `:boardId` child route
- Create: `app/javascript/dashboard/routes/dashboard/kanban/BoardList.vue`
- Create: `app/javascript/dashboard/routes/dashboard/kanban/constants.js`

**Interfaces:**
- Consumes: store actions `kanban/fetchBoards`, `kanban/createBoard`, `kanban/deleteBoard`; getter `kanban/getBoards`.
- Produces: `KANBAN_LABEL_PALETTE` (constants.js) — array of 10 hex strings matching `Custom::Kanban::Label::PALETTE`.

- [ ] **Step 1: Write constants** (`routes/dashboard/kanban/constants.js`)

```js
// Keep in sync with Custom::Kanban::Label::PALETTE (app/models/custom/kanban/label.rb).
export const KANBAN_LABEL_PALETTE = [
  '#9F1239', '#B91C1C', '#B45309', '#15803D', '#0F766E',
  '#0E7490', '#1D4ED8', '#4338CA', '#6D28D9', '#BE185D',
];
```

- [ ] **Step 2: Update the routes** (`kanban.routes.js`)

```js
import { frontendURL } from '../../../helper/URLHelper';
import KanbanIndex from './Index.vue';
import BoardList from './BoardList.vue';
import BoardView from './BoardView.vue';

const meta = { permissions: ['administrator', 'agent', 'custom_role'] };

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    component: KanbanIndex,
    children: [
      { path: '', name: 'kanban_view', component: BoardList, meta },
      { path: ':boardId', name: 'kanban_board', component: BoardView, meta, props: true },
    ],
  },
];
```

- [ ] **Step 3: Rewrite `Index.vue`** (paywall → `<router-view>` host)

```vue
<script setup>
// [fazer.ai fork] Native team-tasks Kanban host. Replaces the former Pro paywall.
</script>

<template>
  <router-view />
</template>
```

- [ ] **Step 4: Write `BoardList.vue`**

```vue
<script setup>
import { onMounted, computed, ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const router = useRouter();
const { t } = useI18n();

const boards = useMapGetter('kanban/getBoards');
const newName = ref('');

onMounted(() => store.dispatch('kanban/fetchBoards'));

const createBoard = async () => {
  if (!newName.value.trim()) return;
  const board = await store.dispatch('kanban/createBoard', { name: newName.value.trim() });
  newName.value = '';
  router.push({ name: 'kanban_board', params: { boardId: board.id } });
};

const openBoard = id => router.push({ name: 'kanban_board', params: { boardId: id } });
const hasBoards = computed(() => boards.value.length > 0);
</script>

<template>
  <section class="flex flex-col w-full h-full gap-4 p-6 bg-n-surface-1">
    <header class="flex items-center justify-between">
      <h1 class="text-xl font-medium text-n-slate-12">{{ t('KANBAN.HEADER') }}</h1>
      <div class="flex gap-2">
        <input
          v-model="newName"
          :placeholder="t('KANBAN.BOARD_NAME')"
          class="px-3 py-1.5 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
          @keyup.enter="createBoard"
        />
        <Button sm solid blue :label="t('KANBAN.NEW_BOARD')" @click="createBoard" />
      </div>
    </header>
    <p v-if="!hasBoards" class="text-sm text-n-slate-11">{{ t('KANBAN.EMPTY_BOARDS') }}</p>
    <div v-else class="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <button
        v-for="board in boards"
        :key="board.id"
        class="flex flex-col items-start gap-1 p-4 text-start border rounded-xl border-n-weak bg-n-solid-1 hover:border-n-brand"
        @click="openBoard(board.id)"
      >
        <span class="text-base font-medium text-n-slate-12">{{ board.name }}</span>
        <span v-if="board.owner" class="text-xs text-n-slate-10">{{ t('KANBAN.OWNER') }}</span>
      </button>
    </div>
  </section>
</template>
```

- [ ] **Step 5: Verify build/lint** — `pnpm eslint app/javascript/dashboard/routes/dashboard/kanban` — Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban
git commit -m "feat(kanban): board list replacing the Pro paywall"
```

---

## Task 12: BoardView with drag-and-drop (columns + cards)

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/kanban/BoardView.vue`
- Create: `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanColumn.vue`
- Create: `app/javascript/dashboard/routes/dashboard/kanban/components/KanbanCard.vue`

**Interfaces:**
- Consumes: `kanban/fetchBoard`, `kanban/getCurrentBoard`, `kanban/moveCard`, `kanban/createColumn`, `kanban/createCard`; `vuedraggable`.
- Produces: emits `openCard(card)` up to BoardView (handled in Task 13).

- [ ] **Step 1: Write `KanbanCard.vue`**

```vue
<script setup>
import { computed } from 'vue';
import { KANBAN_LABEL_PALETTE } from '../constants';

const props = defineProps({ card: { type: Object, required: true }, labels: { type: Array, default: () => [] } });
defineEmits(['open']);

const cardLabels = computed(() =>
  props.labels.filter(l => props.card.label_ids?.includes(l.id))
);
</script>

<template>
  <div
    class="flex flex-col gap-1.5 p-2.5 bg-n-solid-1 border border-n-weak rounded-lg cursor-pointer hover:border-n-brand"
    @click="$emit('open', card)"
  >
    <div v-if="cardLabels.length" class="flex flex-wrap gap-1">
      <span
        v-for="label in cardLabels"
        :key="label.id"
        class="h-1.5 w-8 rounded-full"
        :style="{ backgroundColor: label.color }"
      />
    </div>
    <span class="text-sm text-n-slate-12">{{ card.title }}</span>
    <span v-if="card.due_date" class="text-xs text-n-slate-10">{{ card.due_date }}</span>
  </div>
</template>
```

Note: the label swatch uses `:style` for a dynamic palette color — this is the one allowed inline-style exception (color comes from data, not a fixed class). Confirm with the reviewer; alternatively map palette hex → a fixed Tailwind class set in `constants.js`.

- [ ] **Step 2: Write `KanbanColumn.vue`** (uses `vuedraggable` for the card list)

```vue
<script setup>
import draggable from 'vuedraggable';
import { useI18n } from 'vue-i18n';
import KanbanCard from './KanbanCard.vue';

const props = defineProps({
  column: { type: Object, required: true },
  labels: { type: Array, default: () => [] },
});
const emit = defineEmits(['cardMoved', 'addCard', 'openCard']);
const { t } = useI18n();

const onChange = event => {
  if (event.added) {
    emit('cardMoved', {
      cardId: event.added.element.id,
      toColumnId: props.column.id,
      position: event.added.newIndex,
    });
  } else if (event.moved) {
    emit('cardMoved', {
      cardId: event.moved.element.id,
      toColumnId: props.column.id,
      position: event.moved.newIndex,
    });
  }
};
</script>

<template>
  <div class="flex flex-col w-72 shrink-0 gap-2 p-2 bg-n-alpha-black1 rounded-xl">
    <h3 class="px-1 text-sm font-medium text-n-slate-12">{{ column.name }}</h3>
    <draggable
      :list="column.cards"
      group="kanban-cards"
      item-key="id"
      class="flex flex-col gap-2 min-h-[8px]"
      @change="onChange"
    >
      <template #item="{ element }">
        <KanbanCard :card="element" :labels="labels" @open="$emit('openCard', element)" />
      </template>
    </draggable>
    <button class="px-1 py-1 text-xs text-start text-n-slate-10 hover:text-n-slate-12" @click="$emit('addCard', column)">
      + {{ t('KANBAN.NEW_CARD') }}
    </button>
  </div>
</template>
```

- [ ] **Step 3: Write `BoardView.vue`**

```vue
<script setup>
import { onMounted, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import KanbanColumn from './components/KanbanColumn.vue';

const props = defineProps({ boardId: { type: [String, Number], required: true } });
const store = useStore();
const { t } = useI18n();

const board = useMapGetter('kanban/getCurrentBoard');
const columns = computed(() => board.value?.columns ?? []);
const labels = computed(() => board.value?.labels ?? []);

onMounted(() => store.dispatch('kanban/fetchBoard', props.boardId));

const onCardMoved = ({ cardId, toColumnId, position }) =>
  store.dispatch('kanban/moveCard', { cardId, toColumnId, position });

const addColumn = () => store.dispatch('kanban/createColumn', { boardId: props.boardId, name: t('KANBAN.NEW_COLUMN') });
// openCard / addCard wired in Task 13 (CardDialog)
</script>

<template>
  <section v-if="board" class="flex flex-col w-full h-full bg-n-surface-1">
    <header class="flex items-center gap-3 px-4 py-3 border-b border-n-weak">
      <h1 class="text-lg font-medium text-n-slate-12">{{ board.name }}</h1>
    </header>
    <div class="flex flex-1 gap-3 p-4 overflow-x-auto">
      <KanbanColumn
        v-for="column in columns"
        :key="column.id"
        :column="column"
        :labels="labels"
        @card-moved="onCardMoved"
      />
      <button class="w-72 shrink-0 h-10 text-sm rounded-xl border border-dashed border-n-weak text-n-slate-10" @click="addColumn">
        + {{ t('KANBAN.NEW_COLUMN') }}
      </button>
    </div>
  </section>
</template>
```

- [ ] **Step 4: Lint** — `pnpm eslint app/javascript/dashboard/routes/dashboard/kanban` — Expected: no errors.

- [ ] **Step 5: Manual smoke test** — `pnpm dev`, open `/app/accounts/<id>/kanban`, create a board, add columns/cards, drag a card between columns, reload → the move persisted.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban
git commit -m "feat(kanban): board view with drag-and-drop columns and cards"
```

---

## Task 13: Card dialog, filters, and board members

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue`
- Create: `app/javascript/dashboard/routes/dashboard/kanban/components/BoardMembersDialog.vue`
- Modify: `BoardView.vue` (wire open/add card, filters by assignee/label, members button)
- Modify: `app/javascript/dashboard/store/modules/custom/kanban.js` (add `createCard`, `updateCard`, `deleteCard` actions)

**Interfaces:**
- Consumes: `kanban/createCard`, `kanban/updateCard`, `kanban/deleteCard`; agents getter `agents/getAgents` (or `getVerifiedAgents`) for the assignee combobox.

- [ ] **Step 1: Add the card actions to the store** (`store/modules/custom/kanban.js`) — after `moveCard`:

```js
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
```

- [ ] **Step 2: Write `CardDialog.vue`** — Dialog with title, description, assignee (agents combobox), labels (multi-select from board labels), due date. Emits nothing; dispatches store actions directly using `boardId`.

```vue
<script setup>
import { ref, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, default: null },
  columnId: { type: [String, Number], default: null },
  labels: { type: Array, default: () => [] },
});
const store = useStore();
const { t } = useI18n();
const dialogRef = ref(null);
const agents = useMapGetter('agents/getAgents');

const form = ref({ title: '', description: '', assignee_id: null, due_date: null, label_ids: [] });

watch(
  () => props.card,
  card => {
    form.value = card
      ? { title: card.title, description: card.description, assignee_id: card.assignee_id, due_date: card.due_date, label_ids: [...(card.label_ids || [])] }
      : { title: '', description: '', assignee_id: null, due_date: null, label_ids: [] };
  },
  { immediate: true }
);

const open = () => dialogRef.value?.open();
defineExpose({ open });

const save = async () => {
  if (props.card) {
    await store.dispatch('kanban/updateCard', { boardId: props.boardId, id: props.card.id, ...form.value });
  } else {
    await store.dispatch('kanban/createCard', { boardId: props.boardId, column_id: props.columnId, ...form.value });
  }
  dialogRef.value?.close();
};

const remove = async () => {
  await store.dispatch('kanban/deleteCard', { boardId: props.boardId, id: props.card.id });
  dialogRef.value?.close();
};
</script>

<template>
  <Dialog ref="dialogRef" :title="t('KANBAN.CARD.TITLE')" :show-confirm-button="false" :show-cancel-button="false">
    <div class="flex flex-col gap-3">
      <input v-model="form.title" :placeholder="t('KANBAN.CARD.TITLE')" class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12" />
      <textarea v-model="form.description" :placeholder="t('KANBAN.CARD.DESCRIPTION')" rows="3" class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12" />
      <select v-model="form.assignee_id" class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12">
        <option :value="null">—</option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">{{ agent.name }}</option>
      </select>
      <input v-model="form.due_date" type="date" class="px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12" />
      <div class="flex flex-wrap gap-2">
        <button
          v-for="label in labels"
          :key="label.id"
          type="button"
          class="h-6 px-2 text-xs rounded-full"
          :style="{ backgroundColor: label.color, color: '#fff', opacity: form.label_ids.includes(label.id) ? 1 : 0.4 }"
          @click="form.label_ids.includes(label.id) ? form.label_ids.splice(form.label_ids.indexOf(label.id), 1) : form.label_ids.push(label.id)"
        >
          {{ label.name }}
        </button>
      </div>
      <div class="flex justify-between">
        <button v-if="card" class="text-sm text-n-ruby-11" @click="remove">{{ t('KANBAN.CARD.DELETE') }}</button>
        <button class="px-3 py-1.5 text-sm text-white rounded-lg bg-n-brand" @click="save">{{ t('KANBAN.CARD.SAVE') }}</button>
      </div>
    </div>
  </Dialog>
</template>
```

Note: ensure the `agents` store is loaded (dispatch `agents/get` in BoardView `onMounted` if not already loaded elsewhere). Confirm the exact getter name (`agents/getAgents` vs `agents/getVerifiedAgents`).

- [ ] **Step 3: Wire BoardView** — add a `CardDialog` ref + `openCard`/`addCard` handlers passed into `KanbanColumn` via `@open-card`/`@add-card`, and client-side filters (assignee + label) computed over `column.cards`. Add a filter bar in the header using `KANBAN.FILTERS.*` keys.

```js
// BoardView.vue <script setup> additions
import { ref } from 'vue';
import CardDialog from './components/CardDialog.vue';
const cardDialog = ref(null);
const activeCard = ref(null);
const activeColumnId = ref(null);
const assigneeFilter = ref(null);
const labelFilter = ref(null);

const openCard = card => { activeCard.value = card; activeColumnId.value = null; cardDialog.value.open(); };
const addCard = column => { activeCard.value = null; activeColumnId.value = column.id; cardDialog.value.open(); };

const visibleCards = column =>
  column.cards.filter(c =>
    (!assigneeFilter.value || c.assignee_id === assigneeFilter.value) &&
    (!labelFilter.value || c.label_ids?.includes(labelFilter.value))
  );
```

Pass `:cards="visibleCards(column)"` into `KanbanColumn` (add a `cards` prop that defaults to `column.cards`), and render `<CardDialog ref="cardDialog" :board-id="boardId" :card="activeCard" :column-id="activeColumnId" :labels="labels" />`.

- [ ] **Step 4: Write `BoardMembersDialog.vue`** — owner-only dialog listing current members (from `KanbanAPI.getMembers`) with add (agents combobox) / remove. Shown via a "Members" button in BoardView visible only when `board.owner`.

```vue
<script setup>
import { ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import KanbanAPI from 'dashboard/api/custom/kanban';

const props = defineProps({ boardId: { type: [String, Number], required: true } });
const { t } = useI18n();
const dialogRef = ref(null);
const members = ref([]);
const agents = useMapGetter('agents/getAgents');

const load = async () => { members.value = (await KanbanAPI.getMembers(props.boardId)).data.payload; };
const open = async () => { await load(); dialogRef.value?.open(); };
defineExpose({ open });

const add = async userId => { await KanbanAPI.addMember(props.boardId, userId); await load(); };
const remove = async memberId => { await KanbanAPI.removeMember(props.boardId, memberId); await load(); };
</script>

<template>
  <Dialog ref="dialogRef" :title="t('KANBAN.MEMBERS')" :show-confirm-button="false" :show-cancel-button="false">
    <ul class="flex flex-col gap-2">
      <li v-for="m in members" :key="m.id" class="flex items-center justify-between text-sm text-n-slate-12">
        <span>{{ m.name }}<span v-if="m.owner" class="ms-2 text-xs text-n-slate-10">({{ t('KANBAN.OWNER') }})</span></span>
        <button v-if="!m.owner" class="text-xs text-n-ruby-11" @click="remove(m.id)">✕</button>
      </li>
    </ul>
    <select class="w-full px-3 py-2 mt-3 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12" @change="add($event.target.value)">
      <option value="">{{ t('KANBAN.ADD_MEMBER') }}</option>
      <option v-for="agent in agents" :key="agent.id" :value="agent.id">{{ agent.name }}</option>
    </select>
  </Dialog>
</template>
```

- [ ] **Step 5: Lint + manual test** — `pnpm eslint app/javascript/dashboard/routes/dashboard/kanban`; then in `pnpm dev`: open a card, edit title/assignee/labels/due date, save → persists after reload; filter by assignee and label; as owner, add/remove a member; as a non-member, the board 404s.

- [ ] **Step 6: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban app/javascript/dashboard/store/modules/custom/kanban.js
git commit -m "feat(kanban): card dialog, filters and board membership UI"
```

---

## Task 14: Document the fork changes

**Files:**
- Modify: `.claude/CLAUDE.md` ("Mudanças nossas")

- [ ] **Step 1: Add an entry** under "Mudanças nossas em arquivos do upstream" describing: the new `custom_kanban_*` tables/models/controllers (all new, namespace `Custom::Kanban`), the `config/routes.rb` block, the repurposed `routes/dashboard/kanban/Index.vue` (paywall → host) and `kanban.routes.js` child routes, the `store/index.js` + `mutation-types.js` additions, the `app/models/account.rb` one-liner (`include Custom::AccountKanban`), and the i18n overlay `kanban.json` (paywall keys removed). Note the palette is duplicated (model ↔ `constants.js`) — keep in sync. State how to revert (drop tables, remove routes block, restore the paywall Index.vue, remove the module registration and the Account include).

- [ ] **Step 2: Commit**

```bash
git add .claude/CLAUDE.md
git commit -m "docs(kanban): record upstream edits in Mudanças nossas"
```

---

## Self-Review notes

- **Spec coverage:** boards/columns/cards/labels/members models + migrations (Tasks 1–3); access scope + owner rules (Tasks 1, 4, 7); REST API incl. move/reorder (Tasks 4–7); reused route/icon (Task 11); board list, drag-and-drop board, card dialog, filters, membership UI (Tasks 11–13); i18n en/pt_BR/es (Task 10); no real-time (store refetches on change). All design §requirements map to a task.
- **Open confirmations for the implementer (resolve at first use, don't guess):** exact `User` admin helper (`administrator?` vs `AccountUser` role query) in `accessible_by`; `render_unauthorized` availability; agents getter name (`getAgents` vs `getVerifiedAgents`); whether the label color inline `:style` is acceptable to the reviewer or should become a fixed Tailwind class map. These are the only ambiguities and each is flagged inline where it occurs.
- **Type consistency:** store action/getter names (`moveCard`, `getCurrentBoard`), API methods (`moveCard`, `reorderColumns`), and event names (`cardMoved`, `openCard`, `addCard`) are used consistently across Tasks 8–13.
