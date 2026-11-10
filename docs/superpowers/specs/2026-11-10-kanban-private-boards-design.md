# Kanban private boards — access restricted to members

**Date:** 2026-11-10
**Status:** Approved
**Area:** Native team-tasks Kanban (fazer.ai fork)

## Problem

A Kanban board is meant to be private to its team. Today, access leaks: the
`Custom::Kanban::Board.accessible_by` scope grants every board in the account to
any **account administrator**, so an admin sees everyone's personal boards. In a
small accounting team where several people are administrators, the effect is that
"everyone sees everyone's board", defeating the point of a private board.

## Goal

Make board access depend **only on membership**. The account role
(`administrator`/`agent`) no longer influences board visibility. A board is
visible and mutable solely by its members:

- The creator is added as a member on creation (unchanged).
- The owner adds other members when they want to share (unchanged).
- An administrator who is not a member sees nothing of that board — not in the
  list, not via direct access, not through real-time updates.

## Non-goals (explicitly out of scope)

- **Admin "escape hatch"** to delete an orphaned board (owner left the company).
  Not needed today; can be added later if a real case appears.
- **A per-board "share with the whole account" toggle.** Larger scope, YAGNI now.

## Design

Access already funnels through a single scope, so the change is small and
centralized.

### 1. `app/models/custom/kanban/board.rb` — drop the admin clause

The `accessible_by` scope stops special-casing administrators:

```ruby
# A user can access a board only when they are a member of it. The account role
# (administrator/agent) does not grant visibility — boards are private to their
# members (see docs/superpowers/specs/2026-11-10-kanban-private-boards-design.md).
scope :accessible_by, lambda { |account_user|
  where(account_id: account_user.account_id)
    .joins(:members)
    .where(custom_kanban_board_members: { user_id: account_user.user_id })
    .distinct
}
```

This single change covers every read path, because they all go through
`accessible_by`:

- `BoardsController#index` (list) and `#set_board` (show/update/destroy lookup).
- `BaseController#current_board`, which every nested resource (columns, cards,
  labels, members, comments, attachments) loads before acting. A non-member
  admin therefore gets a `404` on any board they are not a member of, exactly
  like any other outsider.

### 2. `app/controllers/api/v1/accounts/custom/kanban/base_controller.rb` — real-time to members only

The real-time broadcast must not reach a non-member admin (they can no longer
open the board). `board_update_tokens` simplifies to the board's members:

```ruby
# Everyone who can have the board open gets live updates: its members. Account
# role no longer grants access, so admins who are not members are not notified.
def board_update_tokens
  @current_board.member_users.pluck(:pubsub_token).compact
end
```

Update the header comments in `base_controller.rb:1-2` and
`boards_controller.rb:1` to say access = member (drop "or account admin").

## Tests

Three existing specs assert the old "admin sees everything" behavior and get
inverted; the member-access and outsider-denial specs stay as-is.

- `spec/models/custom/kanban/board_spec.rb` — the example
  `includes every account board for an administrator` becomes: an administrator
  who is **not** a member is excluded from `accessible_by`
  (`not_to include(board)`).
- `spec/controllers/api/v1/accounts/custom/kanban/boards_controller_spec.rb` —
  `lists every board for an administrator` becomes: a non-member administrator's
  list does **not** contain boards they are not a member of.
- `spec/controllers/api/v1/accounts/custom/kanban/broadcast_spec.rb` —
  `also broadcasts to account administrators who are not members` becomes: the
  broadcast token list does **not** include a non-member admin's token
  (`not_to include`). The member-tokens broadcast example is unchanged.

No new behavior is introduced, so no new spec files — only the three inversions.

## Docs

- `.claude/CLAUDE.md` — in the Kanban entry under "Mudanças nossas", change the
  access description to "acesso por quadro: **membro**; só o dono gerencia
  membros/apaga" (remove "OU `administrator` da conta").
- Memory `kanban-feature-status` — same correction in its access description.

## Delivery & operational note

Branch `fix/kanban-private-boards` → PR on origin (squash) → cut release
`…-custom.N` → HML → PRD.

On rollout, boards an admin previously saw **only** by virtue of being an admin
will disappear for that admin — this is the intended effect. No board is
orphaned: the creator is always a member, so every existing board keeps at least
its owner.
