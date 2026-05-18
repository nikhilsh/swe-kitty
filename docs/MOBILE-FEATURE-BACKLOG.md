# Mobile Feature Backlog

Date: 2026-05-18

## Purpose

This document turns the KittyLitter reference into a concrete product backlog for `swe-kitty`.

It is not a vague "make the app nicer" note. It is the next implementation plan for making the current shell behave like a real mobile client for our harness.

## What We Have Now

Current mobile chat surfaces are extremely thin:

- [apps/ios/Sources/Views/ChatTab.swift](/root/developer/projects/kitty-swe/apps/ios/Sources/Views/ChatTab.swift:1)
  - flat `ScrollView`
  - one text bubble per event
  - no typed rendering beyond role + text + file list
- [apps/android/app/src/main/kotlin/sh/nikhil/swekitty/ui/ChatPage.kt](/root/developer/projects/kitty-swe/apps/android/app/src/main/kotlin/sh/nikhil/swekitty/ui/ChatPage.kt:1)
  - same basic shape in Compose

This is enough for smoke testing transport, but not enough for serious dogfooding.

## What KittyLitter Has That We Need

From upstream `litter`:

- iOS view tree includes:
  - `ConversationView.swift`
  - `MessageBubbleView.swift`
  - `ToolCallCardView.swift`
  - `ImageGenerationToolCallView.swift`
  - `ComputerUseToolCallView.swift`
  - `ConversationComposer*`
  - `QuickReplySheet.swift`
  - `DiscoveryView.swift`
  - `SessionsScreen.swift`
  - `InlineHandoffView.swift`
  - `SubagentCardView.swift`
- iOS models include:
  - `ConversationItem.swift`
  - `PendingUserInputRequest+ThreadMatching.swift`
  - `SavedServer.swift`
  - `SavedServerStore.swift`
  - `SavedThreadsStore.swift`
  - `NetworkDiscovery.swift`
  - `StreamingRendererCoordinator.swift`
- shared Rust bridge includes:
  - `conversation.rs`
  - `hydration.rs`
  - `discovery.rs`
  - `saved_apps.rs`
  - `session/`
  - `store/`
  - `transport/`
  - `types/`
  - `widget_guidelines.rs`

Interpretation:

- KittyLitter is not just a styled chat bubble app.
- It has a richer conversation model, richer tool/rendering model, richer saved-server/session model, and richer shared core.

## Highest-Value Gaps

### 1. Conversation rendering is too primitive

What we need:

- typed transcript items instead of one flat `ChatEvent`
- proper user bubble vs assistant bubble vs tool-call card treatment
- markdown rendering for assistant content
- code-block rendering
- diff rendering
- expandable long text sections
- richer timestamp / status / metadata presentation

Why:

- KittyLitter treats the conversation as structured content, not just plain strings
- this is the single most visible gap in daily use

## 2. Tool calls need first-class UI

What we need:

- dedicated tool-call cards
- collapsed summary + expandable details
- status coloring for:
  - in progress
  - success
  - failure
- sections for:
  - key/value metadata
  - text output
  - JSON
  - code / command output
  - diffs
  - progress timelines

Why:

- upstream `ToolCallCardView.swift` is one of the most important practical surfaces
- agent work is hard to follow without this

## 3. Pending user input needs explicit UI

What we need:

- detect and surface pending `request_user_input` state
- match requests to the active thread/session
- render selectable options as native cards/buttons
- support 1-3 short questions cleanly
- keep the request inline in the transcript until answered

Why:

- this is one of the key mobile affordances you explicitly called out
- a raw text dump of user-input requests is not acceptable

## 4. Images need real rendering

What we need:

- inline image blocks for agent-produced images
- upload/attach images from the composer
- image preview / tap-to-expand behavior
- consistent image handling on both iOS and Android

Why:

- KittyLitter has explicit image-related conversation/tool surfaces
- our current app barely treats images as a first-class message element

## 5. Composer needs to become a real mobile composer

What we need:

- attachment support
- better multiline text editing
- context strip / pinned context display
- quick replies / suggestion chips
- clearer send state and disabled state
- eventually mentions for files, skills, plugins if our harness supports them

Why:

- upstream has a full `ConversationComposer*` set
- our current composer is a text field plus send button

## 6. Session and server management are too weak

What we need:

- multiple saved servers, not one remembered endpoint
- server pills / rows with live health
- better session list
- better session recovery / hydration
- clear active agent/session state
- discovery support where appropriate

Why:

- upstream has explicit `SavedServerStore`, `DiscoveryView`, `SessionsScreen`, and related support
- the current shell still behaves like a one-server demo

## 7. Handoff / subagent / multi-agent surfaces are missing

What we need:

- visible agent badges in conversation and session headers
- subagent / child-thread cards
- inline handoff surfaces
- better `switch_agent` UX and state visibility

Why:

- this is where `swe-kitty` should exceed a generic Codex mobile client
- our harness semantics need dedicated UI, not hidden protocol behavior

## 8. Streaming behavior needs to feel native

What we need:

- bottom-anchor policy while streaming
- don't yank scroll if the user is reading older content
- better incremental rendering of assistant output
- separate live/finished render paths if needed

Why:

- upstream `ConversationView.swift` has explicit streaming viewport policy and render coordination
- our current "always jump to bottom on event count change" behavior is too crude

## 9. Browser / memory / preview surfaces need stronger integration

What we need:

- tighter browser tab integration with conversation actions
- better memory/handoff preview surfaces
- richer state between session, browser preview, and transcript

Why:

- these are part of the actual product promise, not side tabs

## Recommended Execution Order

### Package 1: Conversation foundation

- define richer transcript item types in shared core
- add typed UI models on iOS and Android
- replace flat chat rows with:
  - user bubble
  - assistant markdown bubble
  - tool-call card
  - system/status row

Goal:

- make the conversation screen feel like a product, not a log viewer

### Package 2: Pending user input + quick replies

- add pending user-input state to core
- match pending requests to active session/thread
- render native answer sheets/cards
- support direct response submission

Goal:

- mobile can complete agent flows cleanly when the agent asks for structured input

### Package 3: Images + attachments

- render agent images inline
- add composer image attach flow on both platforms
- improve preview/open behavior

Goal:

- parity for image-heavy tasks

### Package 4: Sessions + saved servers

- move from one-endpoint persistence to multi-server persistence
- add server management list and health status
- add better session hydration/recovery

Goal:

- make the app viable for real repeated use, not one pairing at a time

### Package 5: `swe-kitty` differentiators

- inline handoff view
- subagent cards
- multi-agent session state
- memory/handoff preview improvements

Goal:

- product-specific value beyond upstream parity

## Platform-Specific Direction

### iOS first

Priority files to replace or refactor heavily:

- [apps/ios/Sources/Views/ChatTab.swift](/root/developer/projects/kitty-swe/apps/ios/Sources/Views/ChatTab.swift:1)
- [apps/ios/Sources/Views/ProjectView.swift](/root/developer/projects/kitty-swe/apps/ios/Sources/Views/ProjectView.swift:1)
- [apps/ios/Sources/Views/ProjectListView.swift](/root/developer/projects/kitty-swe/apps/ios/Sources/Views/ProjectListView.swift:1)
- [apps/ios/Sources/SessionStore.swift](/root/developer/projects/kitty-swe/apps/ios/Sources/SessionStore.swift:1)

Add likely new groups:

- `Views/Conversation/`
- `Views/Sessions/`
- `Models/Conversation/`
- `Models/Servers/`

### Android second but parallel-ready

Priority files to replace or refactor heavily:

- [apps/android/app/src/main/kotlin/sh/nikhil/swekitty/ui/ChatPage.kt](/root/developer/projects/kitty-swe/apps/android/app/src/main/kotlin/sh/nikhil/swekitty/ui/ChatPage.kt:1)
- `ProjectScreen.kt`
- `ProjectListScreen.kt`
- [apps/android/app/src/main/kotlin/sh/nikhil/swekitty/SessionStore.kt](/root/developer/projects/kitty-swe/apps/android/app/src/main/kotlin/sh/nikhil/swekitty/SessionStore.kt:1)

Likely add:

- conversation component package
- server/session state package
- richer shared UI theme tokens

## Shared Core Work Required

Current `core/` will need to grow beyond:

- terminal stream
- flat chat events
- basic session creation

Likely additions:

- typed conversation items
- pending user-input request state
- richer tool-call payloads
- image attachment descriptors
- saved server/session persistence support
- hydration/resume improvements

## Recommendation

Do not spend the next cycle on isolated styling tweaks.

The next meaningful mobile milestone should be:

1. replace flat chat rendering with typed conversation rendering
2. add pending user-input UI
3. add image rendering + attachments
4. strengthen sessions/servers

That is the shortest route from "shell" to "credible KittyLitter-style mobile client."
