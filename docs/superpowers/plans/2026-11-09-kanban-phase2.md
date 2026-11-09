# Kanban Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real-time board updates, card comments, and card attachments to the native team-tasks Kanban (phase 2).

**Architecture:** New `custom_kanban_card_comments` table + `Custom::Kanban::CardComment`; ActiveStorage `has_many_attached :files` on the card; nested REST controllers for comments and attachments under `cards`; a single `after_action` in the Kanban base controller broadcasts `kanban.board.updated` (via the existing `ActionCableBroadcastJob`) to board members' pubsub tokens; the dashboard adds one event handler that refetches the open board. UI adds comments/attachments sections to the existing `CardDialog`.

**Tech Stack:** Rails 7.2 / ActiveRecord / ActiveStorage, ActionCable, RSpec, Vue 3 `<script setup>`, Vuex, vue-i18n, Tailwind (`n-*` tokens).

## Global Constraints

- New code in NEW files under `custom` namespaces; upstream edits minimal and logged in `.claude/CLAUDE.md` → "Mudanças nossas" (this phase edits: `config/routes.rb`, `app/javascript/dashboard/helper/actionCable.js`, `_card.json.jbuilder`, `app/models/custom/kanban/card.rb`, `db/schema.rb`).
- Migrations: real timestamp, idempotent (`unless table_exists?`). No raw SQL. Prefer associations + `dependent: :destroy`.
- Styling: Tailwind utilities only, `n-*` tokens. Vue: Composition API `<script setup>`, PascalCase components, camelCase events, no bare strings (use i18n), typed `defineProps`.
- i18n: fork keys in `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/kanban.json`, every key in all three. Never touch upstream locale trees.
- RuboCop 150-char lines; compact `module/class`.
- **No local Ruby/Postgres on this workstation** — backend specs validate on CI (`run_foss_spec.yml`, dispatch with explicit spec FILE paths, never directories). `db/schema.rb` is hand-edited (CI `db:schema:load` + `maintain_test_schema!` proves it consistent when `backend-tests` passes). Commit with `git commit --no-verify` (husky needs `bundle`).
- ESLint: run `eslint:fix`; Windows working tree is CRLF so verify real errors with `--rule '{"prettier/prettier":"off"}'`. CI only fails on errors, not warnings.
- Permission model carried from phase 1: board access = member OR account administrator; access-denied lookups → **404**; author/owner-only actions by others → **403**; invalid input → **422**.
- Attachment size limit: **40 MB** per file. Comments are plain text (no markdown/mentions).
- Brand `fazer.ai` lowercase. Conventional Commits, no "Claude" in messages. Work on branch `feat/kanban-phase2`.

---

## File Structure

**Backend (new):**
- `db/migrate/20261109151230_create_custom_kanban_card_comments.rb`
- `app/models/custom/kanban/card_comment.rb`
- `app/controllers/api/v1/accounts/custom/kanban/comments_controller.rb`
- `app/controllers/api/v1/accounts/custom/kanban/attachments_controller.rb`
- `app/views/api/v1/accounts/custom/kanban/comments/show.json.jbuilder`

**Backend (edit, logged):**
- `app/models/custom/kanban/card.rb` (comments assoc, `has_many_attached :files`, size validation, `url_helpers`)
- `app/controllers/api/v1/accounts/custom/kanban/base_controller.rb` (`after_action :broadcast_board_update`)
- `app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder` (comments + attachments)
- `config/routes.rb` (nested `comments`, `attachments`)
- `db/schema.rb` (new table + version bump)

**Frontend (new):**
- `app/javascript/dashboard/routes/dashboard/kanban/components/CardComments.vue`
- `app/javascript/dashboard/routes/dashboard/kanban/components/CardAttachments.vue`

**Frontend (edit, logged):**
- `app/javascript/dashboard/api/custom/kanban.js` (comment/attachment methods)
- `app/javascript/dashboard/store/modules/custom/kanban.js` (actions + `onBoardUpdated`)
- `app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue` (render sections)
- `app/javascript/dashboard/helper/actionCable.js` (event + handler)
- `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/kanban.json`

---

## Task 1: CardComment model + attachments on Card

**Files:**
- Create: `db/migrate/20261109151230_create_custom_kanban_card_comments.rb`, `app/models/custom/kanban/card_comment.rb`
- Modify: `app/models/custom/kanban/card.rb`, `db/schema.rb`
- Test: `spec/models/custom/kanban/card_comment_spec.rb`

**Interfaces:**
- Produces: `Custom::Kanban::CardComment` (`belongs_to :card`, `belongs_to :user`, `content`); `Card#comments`, `Card#files` (ActiveStorage, max 40 MB each), `Card#file_url(attachment)`.

- [ ] **Step 1: Write the migration** (`db/migrate/20261109151230_create_custom_kanban_card_comments.rb`)

```ruby
class CreateCustomKanbanCardComments < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:custom_kanban_card_comments)

    create_table :custom_kanban_card_comments do |t|
      t.bigint :custom_kanban_card_id, null: false
      t.bigint :user_id, null: false
      t.text :content, null: false
      t.timestamps
    end
    add_index :custom_kanban_card_comments, :custom_kanban_card_id
  end
end
```

- [ ] **Step 2: Add the table to `db/schema.rb`** — insert alphabetically right after the `create_table "custom_kanban_card_labels"` block (before `custom_kanban_cards`):

```ruby
  create_table "custom_kanban_card_comments", force: :cascade do |t|
    t.bigint "custom_kanban_card_id", null: false
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_kanban_card_id"], name: "index_custom_kanban_card_comments_on_custom_kanban_card_id"
  end
```

Then bump the schema version line to the new migration:
```ruby
ActiveRecord::Schema[7.2].define(version: 2026_11_09_151230) do
```

- [ ] **Step 3: Write the CardComment model** (`app/models/custom/kanban/card_comment.rb`)

```ruby
# [fazer.ai fork] A plain-text comment on a Kanban card (phase 2).
class Custom::Kanban::CardComment < ApplicationRecord
  self.table_name = 'custom_kanban_card_comments'

  belongs_to :card, class_name: 'Custom::Kanban::Card', foreign_key: :custom_kanban_card_id, inverse_of: :comments
  belongs_to :user

  validates :content, presence: true

  default_scope { order(:created_at, :id) }

  def authored_by?(a_user)
    user_id == a_user.id
  end
end
```

- [ ] **Step 4: Extend the Card model** (`app/models/custom/kanban/card.rb`) — add inside the class:

```ruby
  include Rails.application.routes.url_helpers

  has_many :comments, class_name: 'Custom::Kanban::CardComment',
                      foreign_key: :custom_kanban_card_id, inverse_of: :card, dependent: :destroy
  has_many_attached :files

  FILE_SIZE_LIMIT = 40.megabytes

  validate :files_within_size_limit

  def file_url(attachment)
    url_for(attachment)
  end

  private

  def files_within_size_limit
    files.each do |file|
      errors.add(:files, 'is too large') if file.blob.present? && file.blob.byte_size > FILE_SIZE_LIMIT
    end
  end
```

Note: `url_for` needs a host. The project already serializes attachment URLs the same way (`app/models/attachment.rb#file_url` uses `url_for(file)` with `include Rails.application.routes.url_helpers`); `default_url_options` is configured app-wide, so no extra host wiring is needed here.

- [ ] **Step 5: Write the failing spec** (`spec/models/custom/kanban/card_comment_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe Custom::Kanban::CardComment do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:board) { Custom::Kanban::Board.create!(account: account, name: 'Fiscal') }
  let(:column) { board.columns.create!(name: 'To do', position: 0) }
  let(:card) { column.cards.create!(title: 'x', position: 0) }

  it 'requires content' do
    comment = described_class.new(card: card, user: user)
    expect(comment).not_to be_valid
  end

  it 'is destroyed with its card' do
    card.comments.create!(user: user, content: 'hi')
    expect { card.destroy! }.to change(described_class, :count).by(-1)
  end

  it 'knows its author' do
    comment = card.comments.create!(user: user, content: 'hi')
    expect(comment.authored_by?(user)).to be(true)
  end
end
```

- [ ] **Step 6: Run it** — `bundle exec rspec spec/models/custom/kanban/card_comment_spec.rb` — Expected: PASS (verified on CI).

- [ ] **Step 7: Commit**

```bash
git add db/migrate app/models/custom/kanban/card_comment.rb app/models/custom/kanban/card.rb db/schema.rb spec/models/custom/kanban/card_comment_spec.rb
git commit --no-verify -m "feat(kanban): card comment model and card attachments"
```

---

## Task 2: Comments controller + routes + card payload

**Files:**
- Create: `app/controllers/api/v1/accounts/custom/kanban/comments_controller.rb`, `app/views/api/v1/accounts/custom/kanban/comments/show.json.jbuilder`
- Modify: `config/routes.rb`, `app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder`
- Test: `spec/controllers/api/v1/accounts/custom/kanban/comments_controller_spec.rb`

**Interfaces:**
- Consumes: `current_board`, `authorize_owner!` (phase-1 base controller); `Card#comments` (Task 1).
- Produces: `POST/PATCH/DELETE .../cards/:card_id/comments[/:id]`; card JSON now has `comments: [{ id, author_id, author_name, content, created_at }]`.

- [ ] **Step 1: Add routes** — in `config/routes.rb`, inside the existing `resources :cards do` block (phase 1), add the two nested resources:

```ruby
                resources :cards, only: [:create, :update, :destroy] do
                  patch :move, on: :member
                  resources :comments, only: [:create, :update, :destroy]
                  resources :attachments, only: [:create, :destroy]
                end
```

- [ ] **Step 2: Write the comments controller** (`app/controllers/api/v1/accounts/custom/kanban/comments_controller.rb`)

```ruby
# [fazer.ai fork] Plain-text comments on a Kanban card (phase 2).
class Api::V1::Accounts::Custom::Kanban::CommentsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_card
  before_action :set_comment, only: [:update, :destroy]
  before_action :authorize_author_or_owner!, only: [:update, :destroy]

  def create
    @comment = @card.comments.create!(content: params.require(:content), user: current_user)
    render :show
  end

  def update
    @comment.update!(content: params.require(:content))
    render :show
  end

  def destroy
    @comment.destroy!
    head :ok
  end

  private

  def set_card
    @card = Custom::Kanban::Card.where(custom_kanban_column_id: @current_board.columns.select(:id)).find(params[:card_id])
  end

  def set_comment
    @comment = @card.comments.find(params[:id])
  end

  def authorize_author_or_owner!
    return if @comment.authored_by?(current_user) || @current_board.owned_by?(current_user)

    render json: { error: 'You can only edit your own comments' }, status: :forbidden
  end
end
```

- [ ] **Step 3: Write the comment jbuilder** (`.../comments/show.json.jbuilder`)

```ruby
json.id @comment.id
json.author_id @comment.user_id
json.author_name @comment.user.name
json.content @comment.content
json.created_at @comment.created_at
```

- [ ] **Step 4: Add comments to the card payload** (`.../boards/_card.json.jbuilder`) — append:

```ruby
json.comments card.comments.includes(:user) do |comment|
  json.id comment.id
  json.author_id comment.user_id
  json.author_name comment.user.name
  json.content comment.content
  json.created_at comment.created_at
end
```

- [ ] **Step 5: Write the failing spec** (`spec/controllers/api/v1/accounts/custom/kanban/comments_controller_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe 'Kanban comments API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b.members.create!(user: member)
    b
  end
  let!(:column) { board.columns.create!(name: 'To do', position: 0) }
  let!(:card) { column.cards.create!(title: 'x', position: 0) }

  it 'lets a member add a comment' do
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/comments",
         params: { content: 'hello' }, headers: member.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
    expect(card.comments.last.user).to eq(member)
  end

  it 'forbids editing another user comment (non-owner)' do
    comment = card.comments.create!(user: owner, content: 'orig')
    patch "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/comments/#{comment.id}",
          params: { content: 'edit' }, headers: member.create_new_auth_token, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'lets the board owner delete any comment' do
    comment = card.comments.create!(user: member, content: 'm')
    delete "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/comments/#{comment.id}",
           headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(card.comments.count).to eq(0)
  end
end
```

- [ ] **Step 6: Run it** — `bundle exec rspec spec/controllers/api/v1/accounts/custom/kanban/comments_controller_spec.rb` — Expected: PASS (CI).

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/api/v1/accounts/custom/kanban/comments_controller.rb app/views/api/v1/accounts/custom/kanban/comments app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder spec/controllers/api/v1/accounts/custom/kanban/comments_controller_spec.rb
git commit --no-verify -m "feat(kanban): card comments api"
```

---

## Task 3: Attachments controller + card payload

**Files:**
- Create: `app/controllers/api/v1/accounts/custom/kanban/attachments_controller.rb`
- Modify: `app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder`
- Test: `spec/controllers/api/v1/accounts/custom/kanban/attachments_controller_spec.rb`

**Interfaces:**
- Consumes: `current_board` (phase-1 base); `Card#files` (Task 1).
- Produces: `POST .../cards/:card_id/attachments` (multipart `file`), `DELETE .../cards/:card_id/attachments/:id`; card JSON `attachments: [{ id, filename, file_url, content_type, is_image }]`.

- [ ] **Step 1: Write the attachments controller** (`app/controllers/api/v1/accounts/custom/kanban/attachments_controller.rb`)

```ruby
# [fazer.ai fork] File attachments on a Kanban card (phase 2). Max 40 MB per file.
class Api::V1::Accounts::Custom::Kanban::AttachmentsController < Api::V1::Accounts::Custom::Kanban::BaseController
  before_action :set_card

  def create
    file = params.require(:file)
    return render_too_large if file.size > Custom::Kanban::Card::FILE_SIZE_LIMIT

    @card.files.attach(file)
    blob = @card.files.last.blob
    blob.metadata['uploaded_by'] = current_user.id
    blob.save!
    render 'api/v1/accounts/custom/kanban/boards/card', locals: { card: @card.reload }
  end

  def destroy
    attachment = @card.files.find(params[:id])
    return render_forbidden unless can_remove?(attachment)

    attachment.purge
    head :ok
  end

  private

  def set_card
    @card = Custom::Kanban::Card.where(custom_kanban_column_id: @current_board.columns.select(:id)).find(params[:card_id])
  end

  def can_remove?(attachment)
    attachment.blob.metadata['uploaded_by'] == current_user.id || @current_board.owned_by?(current_user)
  end

  def render_forbidden
    render json: { error: 'You cannot remove this attachment' }, status: :forbidden
  end

  def render_too_large
    render json: { error: 'File is too large' }, status: :unprocessable_entity
  end
end
```

Note: `create` re-renders the `_card` partial so the client gets the updated attachment list. jbuilder can render a partial with `render 'path', locals:`; if that errors in a controller context, instead point `create` at a trivial `attachments/show.json.jbuilder` that does `json.partial! 'api/v1/accounts/custom/kanban/boards/card', card: @card.reload`.

- [ ] **Step 2: Add attachments to the card payload** (`.../boards/_card.json.jbuilder`) — append:

```ruby
json.attachments card.files.map do |file|
  {
    id: file.id,
    filename: file.filename.to_s,
    file_url: card.file_url(file),
    content_type: file.content_type,
    is_image: file.content_type.to_s.start_with?('image/')
  }
end
```

- [ ] **Step 3: Write the failing spec** (`spec/controllers/api/v1/accounts/custom/kanban/attachments_controller_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe 'Kanban attachments API', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b.members.create!(user: member)
    b
  end
  let!(:column) { board.columns.create!(name: 'To do', position: 0) }
  let!(:card) { column.cards.create!(title: 'x', position: 0) }
  let(:file) { fixture_file_upload(Rails.root.join('spec/assets/avatar.png'), 'image/png') }

  it 'attaches a file uploaded by a member' do
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/attachments",
         params: { file: file }, headers: member.create_new_auth_token
    expect(response).to have_http_status(:success)
    expect(card.files.count).to eq(1)
    expect(card.files.last.blob.metadata['uploaded_by']).to eq(member.id)
  end

  it 'forbids a non-uploader non-owner from removing' do
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/attachments",
         params: { file: file }, headers: member.create_new_auth_token
    attachment_id = card.reload.files.last.id
    stranger = create(:user, account: account, role: :agent)
    board.members.create!(user: stranger)
    delete "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards/#{card.id}/attachments/#{attachment_id}",
           headers: stranger.create_new_auth_token
    expect(response).to have_http_status(:forbidden)
  end
end
```

- [ ] **Step 4: Run it** — `bundle exec rspec spec/controllers/api/v1/accounts/custom/kanban/attachments_controller_spec.rb` — Expected: PASS (CI).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/api/v1/accounts/custom/kanban/attachments_controller.rb app/views/api/v1/accounts/custom/kanban/boards/_card.json.jbuilder spec/controllers/api/v1/accounts/custom/kanban/attachments_controller_spec.rb
git commit --no-verify -m "feat(kanban): card attachments api"
```

---

## Task 4: Real-time broadcast on board mutations

**Files:**
- Modify: `app/controllers/api/v1/accounts/custom/kanban/base_controller.rb`
- Test: `spec/controllers/api/v1/accounts/custom/kanban/broadcast_spec.rb`

**Interfaces:**
- Consumes: `@current_board` (phase-1 base); existing `ActionCableBroadcastJob.perform_later(tokens, event, data)`.
- Produces: after any successful mutating request on a nested kanban resource, enqueues `ActionCableBroadcastJob` with event `'kanban.board.updated'`, data `{ board_id: }`, to `@current_board.member_users.pluck(:pubsub_token)`.

- [ ] **Step 1: Add the after_action** (`.../kanban/base_controller.rb`) — add inside the class:

```ruby
  after_action :broadcast_board_update

  # ... keep current_board / authorize_owner! below ...

  def broadcast_board_update
    return if request.get? || !response.successful? || @current_board.nil?

    tokens = @current_board.member_users.pluck(:pubsub_token).compact
    return if tokens.blank?

    ActionCableBroadcastJob.perform_later(tokens, 'kanban.board.updated', { board_id: @current_board.id })
  end
```

(Place `after_action :broadcast_board_update` right after `before_action :current_board`; keep `broadcast_board_update` as a private method alongside the existing private methods.)

- [ ] **Step 2: Write the failing spec** (`spec/controllers/api/v1/accounts/custom/kanban/broadcast_spec.rb`)

```ruby
require 'rails_helper'

RSpec.describe 'Kanban real-time broadcast', type: :request do
  let(:account) { create(:account) }
  let(:owner) { create(:user, account: account, role: :agent) }
  let(:member) { create(:user, account: account, role: :agent) }
  let!(:board) do
    b = Custom::Kanban::Board.create!(account: account, name: 'Fiscal', created_by_id: owner.id)
    b.members.create!(user: owner)
    b.members.create!(user: member)
    b
  end
  let!(:column) { board.columns.create!(name: 'To do', position: 0) }

  it 'broadcasts kanban.board.updated to member tokens after a mutation' do
    expect(ActionCableBroadcastJob).to receive(:perform_later) do |tokens, event, data|
      expect(event).to eq('kanban.board.updated')
      expect(data).to eq({ board_id: board.id })
      expect(tokens).to contain_exactly(owner.pubsub_token, member.pubsub_token)
    end
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: column.id, title: 'new' } }, headers: owner.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
  end

  it 'does not broadcast on a failed (404) request' do
    expect(ActionCableBroadcastJob).not_to receive(:perform_later)
    other = create(:user, account: account, role: :agent)
    post "/api/v1/accounts/#{account.id}/custom/kanban/boards/#{board.id}/cards",
         params: { card: { column_id: column.id, title: 'x' } }, headers: other.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
```

- [ ] **Step 3: Run it** — `bundle exec rspec spec/controllers/api/v1/accounts/custom/kanban/broadcast_spec.rb` — Expected: PASS (CI).

- [ ] **Step 4: Commit**

```bash
git add app/controllers/api/v1/accounts/custom/kanban/base_controller.rb spec/controllers/api/v1/accounts/custom/kanban/broadcast_spec.rb
git commit --no-verify -m "feat(kanban): broadcast board updates to members in real time"
```

---

## Task 5: Frontend API client + store actions

**Files:**
- Modify: `app/javascript/dashboard/api/custom/kanban.js`, `app/javascript/dashboard/store/modules/custom/kanban.js`
- Test: `app/javascript/dashboard/store/modules/custom/specs/kanban.spec.js` (extend)

**Interfaces:**
- Consumes: phase-1 `KanbanAPI`, store `fetchBoard`.
- Produces: API `createComment/updateComment/deleteComment/addAttachment/removeAttachment`; store actions same names + `onBoardUpdated(boardId)`.

- [ ] **Step 1: Add API methods** (`api/custom/kanban.js`) — add inside the class, after the Members block:

```js
  // Comments
  createComment(boardId, cardId, content) {
    return axios.post(`${this.nested(boardId, 'cards')}/${cardId}/comments`, {
      content,
    });
  }

  updateComment(boardId, cardId, id, content) {
    return axios.patch(
      `${this.nested(boardId, 'cards')}/${cardId}/comments/${id}`,
      { content }
    );
  }

  deleteComment(boardId, cardId, id) {
    return axios.delete(
      `${this.nested(boardId, 'cards')}/${cardId}/comments/${id}`
    );
  }

  // Attachments
  addAttachment(boardId, cardId, fileBlob) {
    const formData = new FormData();
    formData.append('file', fileBlob);
    return axios.post(
      `${this.nested(boardId, 'cards')}/${cardId}/attachments`,
      formData,
      { headers: { 'Content-Type': 'multipart/form-data' } }
    );
  }

  removeAttachment(boardId, cardId, id) {
    return axios.delete(
      `${this.nested(boardId, 'cards')}/${cardId}/attachments/${id}`
    );
  }
```

- [ ] **Step 2: Add store actions** (`store/modules/custom/kanban.js`) — add inside `actions`, after `deleteCard`:

```js
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
    if (s.currentBoard && s.currentBoard.id === boardId) dispatch('fetchBoard', boardId);
  },
```

- [ ] **Step 3: Extend the store spec** (`store/modules/custom/specs/kanban.spec.js`) — add:

```js
import { actions } from '../kanban';

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
```

- [ ] **Step 4: Run it** — `pnpm test app/javascript/dashboard/store/modules/custom/specs/kanban.spec.js` — Expected: PASS.

- [ ] **Step 5: Lint + commit**

```bash
npx eslint --fix app/javascript/dashboard/api/custom/kanban.js app/javascript/dashboard/store/modules/custom/kanban.js app/javascript/dashboard/store/modules/custom/specs/kanban.spec.js
git add app/javascript/dashboard/api/custom/kanban.js app/javascript/dashboard/store/modules/custom
git commit --no-verify -m "feat(kanban): store and api for comments, attachments and live refetch"
```

---

## Task 6: ActionCable wiring (frontend)

**Files:**
- Modify: `app/javascript/dashboard/helper/actionCable.js`
- Test: n/a (thin wiring; covered by store spec in Task 5)

**Interfaces:**
- Consumes: store action `kanban/onBoardUpdated` (Task 5).
- Produces: dashboard refetches the open board when a `kanban.board.updated` cable event arrives.

- [ ] **Step 1: Register the event** (`actionCable.js`) — in the `this.events = { ... }` map (around line 56), add a line:

```js
      'kanban.board.updated': this.onKanbanBoardUpdated,
```

- [ ] **Step 2: Add the handler** — add a method on the `ActionCableConnector` class (near the other `on*` handlers):

```js
  onKanbanBoardUpdated = data => {
    this.app.$store.dispatch('kanban/onBoardUpdated', data.board_id);
  };
```

Note: confirm how sibling handlers reach the store in this file (some use `window.$store`, some `this.app.$store`). Match the existing pattern in `actionCable.js` for whichever is used by the neighbouring `on*` handlers.

- [ ] **Step 3: Lint + manual smoke** — `npx eslint --fix app/javascript/dashboard/helper/actionCable.js`. Manual: open the same board in two browser sessions (two agents who are both members); move/create a card or add a comment in one → the other refetches within a moment.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/dashboard/helper/actionCable.js
git commit --no-verify -m "feat(kanban): refetch open board on real-time cable event"
```

---

## Task 7: Card comments & attachments UI

**Files:**
- Create: `app/javascript/dashboard/routes/dashboard/kanban/components/CardComments.vue`, `.../components/CardAttachments.vue`
- Modify: `app/javascript/dashboard/routes/dashboard/kanban/components/CardDialog.vue`
- Test: manual (components are thin; store covered in Task 5)

**Interfaces:**
- Consumes: store actions `createComment/updateComment/deleteComment/addAttachment/removeAttachment`; getter `getCurrentUser` for authorship; `card.comments`, `card.attachments` from the payload.

- [ ] **Step 1: Write `CardComments.vue`**

```vue
<script setup>
import { ref } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, required: true },
  isOwner: { type: Boolean, default: false },
});

const store = useStore();
const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const draft = ref('');

const canManage = comment =>
  comment.author_id === currentUser.value.id || props.isOwner;

const add = async () => {
  if (!draft.value.trim()) return;
  await store.dispatch('kanban/createComment', {
    boardId: props.boardId,
    cardId: props.card.id,
    content: draft.value.trim(),
  });
  draft.value = '';
};

const remove = comment =>
  store.dispatch('kanban/deleteComment', {
    boardId: props.boardId,
    cardId: props.card.id,
    id: comment.id,
  });
</script>

<template>
  <div class="flex flex-col gap-2">
    <h4 class="text-sm font-medium text-n-slate-12">
      {{ t('KANBAN.COMMENTS.TITLE') }}
    </h4>
    <ul v-if="card.comments?.length" class="flex flex-col gap-2">
      <li
        v-for="comment in card.comments"
        :key="comment.id"
        class="flex flex-col gap-0.5 p-2 rounded-lg bg-n-alpha-black1"
      >
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium text-n-slate-11">
            {{ comment.author_name }}
          </span>
          <button
            v-if="canManage(comment)"
            class="text-xs text-n-ruby-11"
            @click="remove(comment)"
          >
            {{ t('KANBAN.COMMENTS.DELETE') }}
          </button>
        </div>
        <p class="text-sm text-n-slate-12 whitespace-pre-wrap">
          {{ comment.content }}
        </p>
      </li>
    </ul>
    <p v-else class="text-xs text-n-slate-10">
      {{ t('KANBAN.COMMENTS.EMPTY') }}
    </p>
    <div class="flex gap-2">
      <input
        v-model="draft"
        :placeholder="t('KANBAN.COMMENTS.PLACEHOLDER')"
        class="flex-1 px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-black1 text-n-slate-12"
        @keyup.enter="add"
      />
      <button
        class="px-3 py-1.5 text-sm text-white rounded-lg bg-n-brand"
        @click="add"
      >
        {{ t('KANBAN.COMMENTS.SEND') }}
      </button>
    </div>
  </div>
</template>
```

- [ ] **Step 2: Write `CardAttachments.vue`**

```vue
<script setup>
import { ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  boardId: { type: [String, Number], required: true },
  card: { type: Object, required: true },
});

const store = useStore();
const { t } = useI18n();
const fileInput = ref(null);

const onPick = async event => {
  const [file] = event.target.files;
  if (!file) return;
  await store.dispatch('kanban/addAttachment', {
    boardId: props.boardId,
    cardId: props.card.id,
    file,
  });
  if (fileInput.value) fileInput.value.value = '';
};

const remove = attachment =>
  store.dispatch('kanban/removeAttachment', {
    boardId: props.boardId,
    cardId: props.card.id,
    id: attachment.id,
  });
</script>

<template>
  <div class="flex flex-col gap-2">
    <h4 class="text-sm font-medium text-n-slate-12">
      {{ t('KANBAN.ATTACHMENTS.TITLE') }}
    </h4>
    <ul v-if="card.attachments?.length" class="flex flex-col gap-2">
      <li
        v-for="attachment in card.attachments"
        :key="attachment.id"
        class="flex items-center gap-2"
      >
        <img
          v-if="attachment.is_image"
          :src="attachment.file_url"
          :alt="attachment.filename"
          class="object-cover rounded size-10"
        />
        <Icon v-else icon="i-lucide-file" class="size-5 text-n-slate-11" />
        <a
          :href="attachment.file_url"
          target="_blank"
          rel="noopener noreferrer"
          class="flex-1 text-sm truncate text-n-brand"
        >
          {{ attachment.filename }}
        </a>
        <button class="text-xs text-n-ruby-11" @click="remove(attachment)">
          {{ t('KANBAN.ATTACHMENTS.REMOVE') }}
        </button>
      </li>
    </ul>
    <p v-else class="text-xs text-n-slate-10">
      {{ t('KANBAN.ATTACHMENTS.EMPTY') }}
    </p>
    <input ref="fileInput" type="file" class="text-xs text-n-slate-11" @change="onPick" />
  </div>
</template>
```

- [ ] **Step 3: Wire both into `CardDialog.vue`** — import and render them below the existing fields, only when editing an existing card (`props.card`). Add to `<script setup>`:

```js
import CardComments from './CardComments.vue';
import CardAttachments from './CardAttachments.vue';
```

Add `isOwner` to the dialog props (the board owner flag, passed from BoardView):

```js
  isOwner: { type: Boolean, default: false },
```

Render after the save/delete row, inside the dialog body, guarded by `v-if="card"`:

```vue
      <template v-if="card">
        <hr class="border-n-weak" />
        <CardComments :board-id="boardId" :card="card" :is-owner="isOwner" />
        <hr class="border-n-weak" />
        <CardAttachments :board-id="boardId" :card="card" />
      </template>
```

Then in `BoardView.vue`, pass `:is-owner="board.owner"` to the `<CardDialog>` element.

Note: after `addAttachment`/`createComment` dispatch, the store refetches the board; `activeCard` in `BoardView` still points at the old object. Make `CardDialog` read the live card from the store by id so the new comment/attachment shows without reopening — in `CardDialog`, derive a `liveCard` computed: `columns.flatMap(c => c.cards).find(c => c.id === props.card?.id)` from `kanban/getCurrentBoard`, and render comments/attachments from `liveCard` (fall back to `props.card`). Keep the top form bound to the local `form` (unchanged) so an in-progress edit is not clobbered.

- [ ] **Step 4: Lint + manual test** — `npx eslint --fix app/javascript/dashboard/routes/dashboard/kanban`. Manual: open a card → add a comment (appears), delete own comment; attach an image (thumbnail) and a PDF (icon + link), remove one; confirm a non-author cannot see a delete control on others' comments.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/routes/dashboard/kanban
git commit --no-verify -m "feat(kanban): comments and attachments ui in the card dialog"
```

---

## Task 8: i18n keys (en, pt_BR, es)

**Files:**
- Modify: `app/javascript/dashboard/i18n/fazer-ai/locale/{en,pt_BR,es}/kanban.json`

- [ ] **Step 1: Add to `en/kanban.json`** under `KANBAN` (alongside existing keys):

```json
    "COMMENTS": {
      "TITLE": "Comments",
      "PLACEHOLDER": "Write a comment",
      "SEND": "Send",
      "DELETE": "Delete",
      "EMPTY": "No comments yet."
    },
    "ATTACHMENTS": {
      "TITLE": "Attachments",
      "REMOVE": "Remove",
      "EMPTY": "No attachments yet.",
      "TOO_LARGE": "File is too large (max 40 MB)."
    }
```

- [ ] **Step 2: Add to `pt_BR/kanban.json`**:

```json
    "COMMENTS": {
      "TITLE": "Comentários",
      "PLACEHOLDER": "Escreva um comentário",
      "SEND": "Enviar",
      "DELETE": "Excluir",
      "EMPTY": "Ainda não há comentários."
    },
    "ATTACHMENTS": {
      "TITLE": "Anexos",
      "REMOVE": "Remover",
      "EMPTY": "Ainda não há anexos.",
      "TOO_LARGE": "Arquivo muito grande (máx. 40 MB)."
    }
```

- [ ] **Step 3: Add to `es/kanban.json`**:

```json
    "COMMENTS": {
      "TITLE": "Comentarios",
      "PLACEHOLDER": "Escribe un comentario",
      "SEND": "Enviar",
      "DELETE": "Eliminar",
      "EMPTY": "Aún no hay comentarios."
    },
    "ATTACHMENTS": {
      "TITLE": "Adjuntos",
      "REMOVE": "Quitar",
      "EMPTY": "Aún no hay adjuntos.",
      "TOO_LARGE": "El archivo es demasiado grande (máx. 40 MB)."
    }
```

- [ ] **Step 4: Validate** — `ruby scripts/i18n/fork_translations.rb check` (CI) and locally `node -e "['en','pt_BR','es'].forEach(l=>JSON.parse(require('fs').readFileSync('app/javascript/dashboard/i18n/fazer-ai/locale/'+l+'/kanban.json')))"`.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/dashboard/i18n/fazer-ai/locale/en/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/pt_BR/kanban.json app/javascript/dashboard/i18n/fazer-ai/locale/es/kanban.json
git commit --no-verify -m "feat(kanban): i18n for comments and attachments (en, pt_BR, es)"
```

---

## Task 9: Document the fork changes

**Files:**
- Modify: `.claude/CLAUDE.md` (extend the existing Kanban entry under "Mudanças nossas")

- [ ] **Step 1: Append a phase-2 note** to the Kanban bullet: new table `custom_kanban_card_comments` + model; `has_many_attached :files` + 40 MB validation on `Custom::Kanban::Card`; new controllers `comments`/`attachments`; `_card.json.jbuilder` now carries `comments[]`/`attachments[]`; `after_action :broadcast_board_update` in the kanban base controller (uses the existing `ActionCableBroadcastJob`, event `kanban.board.updated`, to members' `pubsub_token`); `config/routes.rb` nested `comments`/`attachments`; `actionCable.js` event + handler; store actions + `onBoardUpdated`; `CardComments.vue`/`CardAttachments.vue`; i18n `KANBAN.COMMENTS.*`/`KANBAN.ATTACHMENTS.*`. Note the schema version bump. State revert = drop the table, remove the routes/after_action/actionCable line/handlers and the new files.

- [ ] **Step 2: Commit**

```bash
git add .claude/CLAUDE.md
git commit --no-verify -m "docs(kanban): record phase 2 upstream edits in Mudanças nossas"
```

---

## Self-Review notes

- **Spec coverage:** comments model+API (Tasks 1–2); attachments (Tasks 1,3); card payload carries both (Tasks 2–3); real-time single broadcast point (Task 4) + frontend refetch (Tasks 5–6); UI sections (Task 7); i18n (Task 8); docs (Task 9). Open card not clobbered mid-edit — Task 7 reads a `liveCard` for the comment/attachment lists while the form stays local. All spec §requirements map to a task.
- **Open confirmations (resolve at first use):** whether `actionCable.js` sibling handlers use `this.app.$store` vs `window.$store` (Task 6); whether rendering the `_card` partial from the attachments controller needs a thin `show.json.jbuilder` wrapper (Task 3 note); `fixture_file_upload` asset path `spec/assets/avatar.png` exists (used elsewhere in the suite).
- **Type consistency:** store/API method names (`createComment`, `addAttachment`, `removeAttachment`, `onBoardUpdated`), event string `'kanban.board.updated'`, and payload keys (`comments[].author_id/author_name/content`, `attachments[].filename/file_url/is_image`) are used identically across Tasks 1–8.
