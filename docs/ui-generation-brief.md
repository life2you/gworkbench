# GWorkbench UI Generation Brief

Use this document as the source brief when asking another AI or designer to generate a macOS UI direction for **GWorkbench**.

## Product Summary

GWorkbench is a native macOS developer workbench that combines:

- `gwtm`: local Git worktree creation, opening, inspection, and cleanup
- `gmux`: GitLab merge request creation, batch MR actions, review queue management, and merge flows

The app is not a marketing site. It is a daily-use operations tool for developers who repeatedly manage branches, worktrees, IDE launch flows, and GitLab merge requests.

## Platform

- macOS desktop app
- should feel native, calm, and efficient
- optimized for keyboard + mouse usage
- not touch-first

## Users

Primary user:

- an engineer who manages multiple projects and multiple environment branches every day
- frequently creates worktrees, opens them in an IDE, and drives merge requests through GitLab

Secondary user:

- a technical lead or release operator who wants a compact overview of local branch work and pending merge requests

## Product Goals

1. Make worktree workflows fast and visible.
2. Make MR workflows less noisy and easier to trust.
3. Give local project context and GitLab context in one app.
4. Replace terminal memory burden with clear structure, progress states, and action safety.

## Core Sections

The app has three top-level sections:

1. Worktrees
2. Merge Requests
3. Settings

## Information Architecture

### Worktrees

This section should support:

- project selection
- worktree list browsing
- create new worktree
- optional branch description
- open in IDE
- reveal in Finder
- remove worktree
- optionally remove local branch / remote branch
- progress states for create/open/remove flows

Suggested layout:

- left: project list or project switcher
- center: worktree list
- right: selected worktree detail and actions

### Merge Requests

This section should support:

- GitLab project selection
- list opened MRs
- inspect MR detail
- create single MR
- create batch MR from branch mappings
- approve and merge
- close MR
- show approval state
- show progress while operations run

Suggested layout:

- left: GitLab project list or project switcher
- center: MR queue or MR mapping list
- right: MR detail and action area

### Settings

This section should support:

- local project roots
- worktree root
- default IDE
- GitLab host
- GitLab token
- protected target branches
- environment branches
- branch mapping visibility

## Visual Direction

Design for a **native macOS operations tool**, not a web dashboard and not a consumer app.

The UI should feel:

- quiet
- fast
- structured
- trustworthy
- detail-oriented

Avoid:

- oversized hero sections
- decorative cards everywhere
- gradient-heavy visuals
- marketing-style layouts
- playful or toy-like styling

Prefer:

- split views
- dense but readable rows
- restrained use of color
- strong alignment
- clear grouping
- keyboard-friendly actions
- toolbars, inspector panels, segmented controls, tables, and sidebars

## Tone of the Interface

The interface text should feel:

- direct
- professional
- lightweight
- calm

Avoid over-explaining.

Good:

- Create Worktree
- Open in IDE
- Approve & Merge
- Remove Remote Branch
- Pending Approval

Bad:

- Click here to begin creating a new development worktree for your project

## Worktrees Screen Requirements

Need to show:

- branch name
- project name
- optional description
- path
- updated time or status
- whether it is the main repo or a worktree

Primary actions:

- Create
- Open
- Reveal
- Remove
- Refresh

Important interactions:

- creating a worktree should feel lightweight
- description is optional
- destructive actions should be clear but not dramatic
- progress should not dump raw terminal logs by default

## Merge Requests Screen Requirements

Need to show:

- MR IID
- title
- source branch
- target branch
- author
- approval state
- open / merged / closed status as needed

Primary actions:

- Create MR
- Batch Create
- Approve & Merge
- Close MR
- Refresh

Important interactions:

- approval state should be scannable
- progress should be explicit
- result summaries should be shorter and more polished than terminal output
- protected target behavior should feel safe and understandable

## Settings Screen Requirements

Need to show grouped settings with strong hierarchy.

Suggested groups:

- Local Paths
- IDE
- GitLab
- Merge Policy
- Environment Branches
- Branch Mappings

This page should look like a serious utility settings experience, not a generic form dump.

## Layout Guidance

Use a three-pane desktop structure where useful:

- sidebar
- list/content pane
- detail/inspector pane

For smaller flows, use sheets or popovers for:

- create worktree
- create MR
- batch MR preview
- confirmation steps

## Components to Prefer

- macOS sidebar
- tables or structured lists
- inspector-style detail views
- native search fields
- segmented controls
- toggles
- compact forms
- progress bars
- confirmation dialogs
- toolbar actions

## Example Screen Set

Please generate UI concepts for these screens:

1. App shell with sidebar and top-level navigation
2. Worktrees overview
3. Create Worktree sheet
4. Worktree detail inspector
5. Merge Requests overview
6. Create MR flow
7. Batch MR review flow
8. Settings screen

## Design Constraints

- macOS-first
- no mobile mockups needed
- no landing page
- no onboarding carousel
- no decorative illustrations
- no card-inside-card layouts
- no giant empty whitespace zones
- should look buildable in SwiftUI

## Output Requested From the Other AI

Ask the other AI to produce:

1. a visual design direction for the overall app
2. a wireframe or mockup for each core screen
3. component recommendations
4. interaction notes for create/remove/approve-and-merge flows
5. a concise explanation of why the layout fits a macOS developer operations tool

## Short Prompt You Can Reuse

```text
Design a native macOS desktop app called GWorkbench. It combines Git worktree management and GitLab merge request operations in one tool. The app should feel like a serious daily-use developer operations utility, not a marketing site or generic web dashboard. Use a macOS-style sidebar, dense but readable lists, inspector/detail panels, restrained colors, compact controls, and clear progress states.

Core sections:
1. Worktrees
2. Merge Requests
3. Settings

Please generate desktop UI concepts for:
- app shell
- worktrees overview
- create worktree modal/sheet
- worktree detail panel
- merge requests overview
- create MR flow
- batch MR review flow
- settings page

The UI should be calm, efficient, keyboard-friendly, and clearly buildable in SwiftUI.
```
