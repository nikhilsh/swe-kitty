# PLAN — chat ↔ agent channel (device bug #6 / task #24)

Date: 2026-05-24. Decision needed from the maintainer before implementing.

## The problem (observed on v0.0.30)

The Chat tab is unreliable in both directions because **there is no
structured chat channel — the broker scrapes the agent's TUI output from
the PTY.**

- Inbound: `ws/server.go` "chat" handler writes `msg + "\r"` to the agent's
  PTY stdin and primes `chatScraper.markUserSent`.
- Outbound: `session/chatscraper.go` buffers raw PTY bytes and, after ~700ms
  idle, emits one `view_event {view:"chat", role:"assistant", content}`.
  It strips ANSI and suppresses the echoed input, but is "deliberately not a
  TUI parser."

Failure modes seen on device:
1. **claude send didn't submit** — `\r` doesn't reliably submit Claude
   Code's Ink TUI; the text sat in the prompt until the user pressed Return
   in the Terminal tab.
2. **Reply only when primed from chat** — the scraper only captures a reply
   when `markUserSent` ran (a chat-tab send). Submitting from the Terminal
   tab leaves `awaiting=false`, so claude's reply never reached Chat.
3. **TUI chrome leaks in** — codex's reply showed as
   `Higpt-5.5 default · /root/.swe-kitty/…`: the scraper caught codex's
   status/header line, not just the message.
4. **Interactive prompts missed** — codex's "trust this directory?" prompt
   never surfaced in Chat (only Terminal).

Root issue: both agents run in **full interactive TUI mode** (`claude
--dangerously-skip-permissions`, `codex --dangerously-bypass-…`), the
richest, messiest possible output to scrape.

## Option A — Harden the scraper (broker-only, incremental)

Improve `chatScraper`: strip status/header lines + box-drawing chrome,
better turn-boundary detection, prime on *any* submit (not just chat-tab
sends), surface interactive prompts as pending-input chat events, and fix
submit (bracketed paste / explicit key event instead of a lone `\r`).

- **Pros:** no agent cooperation; works for any CLI agent; pure Go, locally
  unit-testable; ships in days; keeps the one-PTY model.
- **Cons:** fundamentally a heuristic — always fragile against TUI redraws,
  spinners, partial streaming; never fully clean; tool-call/diff cards stay
  approximate.

## Option B — Structured channel (the real fix)

Drive the **chat** tab from each agent's structured/programmatic output mode
rather than the TUI: e.g. Claude Code's `--print --output-format
stream-json` / Agent SDK, and Codex's equivalent JSON/exec mode — surfaced
to the broker over the already-declared `AGENT_CHAT_PORT`
(`chat_event_port_env` in the TOMLs, currently unwired). The Terminal tab
keeps a PTY for those who want the raw TUI.

- **Pros:** clean messages, reliable submit, real tool-call/diff/pending-
  input events — what the conversation cards were built for. The only path
  to a *trustworthy* chat tab.
- **Cons:** agent-specific integration (each agent's structured mode wired
  separately); larger effort; must reconcile "structured chat process" vs
  "PTY terminal process" (two modes, or derive the terminal from structured
  events); exact flags per agent to confirm.

## Recommendation

**Hybrid, in two steps:**

1. **Now (Option A, small):** harden the scraper so Chat is *usable* —
   strip chrome, prime on any submit, fix claude submit. Broker-only,
   testable, ships fast. Makes the v0.0.31-class experience tolerable.
2. **Next (Option B, the real fix):** wire the structured channel over
   `AGENT_CHAT_PORT`, starting with Claude Code's stream-json/SDK. This is
   what makes Chat actually reliable and unlocks proper cards.

**Decision needed:** (a) hybrid as above, (b) jump straight to Option B
(skip scraper hardening), or (c) Option A only for now. I'll implement once
you pick. My lean: **(a)** — it gets you a working chat tab immediately
without blocking on the bigger per-agent integration.
