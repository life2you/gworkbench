# GWorkbench Foundation

## Recommendation

- Build the mac app as a **separate project**
- Keep `gmux` and `gwtm` shipping as CLI/TUI tools
- Share business logic through a Rust core instead of embedding SwiftUI into the existing repos

## Do we need a UI design first?

We do **not** need a polished visual design before coding.

We **do** want a lightweight design pass first:

1. information architecture
2. key workflows
3. rough page structure
4. action hierarchy

That is enough to start the app shell safely.

## App structure

### Sidebar

- Worktrees
- Merge Requests
- Settings

### Worktrees

Primary audience: frequent local branch and IDE operators

Main areas:

- project list
- worktree list
- selected worktree detail
- actions: create, open, remove, refresh

### Merge Requests

Primary audience: release and branch flow operators

Main areas:

- GitLab project list
- MR queue
- MR detail
- actions: create, batch create, approve and merge, close

### Settings

- local project roots
- worktree root
- IDE preference
- GitLab host/token
- protected targets
- environment branches
- branch mapping visibility

## First-pass wireframe

```text
+----------------------------------------------------------------------------------+
| Sidebar         | List / Queue                              | Detail / Actions    |
|-----------------|-------------------------------------------|---------------------|
| Worktrees       | [Project picker]                          | [Selected item]     |
| Merge Requests  | ---------------------------------------   | ------------------  |
| Settings        | branch-a      description      updated     | metadata            |
|                 | branch-b      description      updated     | primary actions     |
|                 | branch-c      description      updated     | secondary actions   |
|                 |                                           | progress / logs     |
+----------------------------------------------------------------------------------+
```

## Phase 1 UX goal

Make the app feel like a practical daily driver, not a marketing shell.

That means:

- dense but readable lists
- clear actions near the selected item
- built-in progress states
- result summaries that are shorter than terminal logs
- native file/folder picking and simple confirmations

## Phase 1 technical plan

1. SwiftUI shell with mock data
2. Rust core crate scaffold
3. extract `gwtm` domain logic into Rust core
4. wire SwiftUI to Rust commands
5. extract `gmux` MR logic into Rust core
