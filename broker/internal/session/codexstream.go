package session

import (
	"bytes"
	"encoding/json"
	"strings"
)

// codexStreamEvent decodes one JSONL line from `codex exec --json`. Codex's
// schema (verified against codex-cli 0.132 on the box): a turn emits
// thread.started{thread_id} → turn.started → item.completed{item:{type,text}}
// → turn.completed. Unlike claude's persistent stream-json stdin, `codex
// exec` is one-shot; multi-turn chat resumes via `codex exec resume
// <thread_id>`. See docs/PLAN-CHAT-CHANNEL.md (task #24, codex slice).
type codexStreamEvent struct {
	Type     string `json:"type"`
	ThreadID string `json:"thread_id"`
	Item     struct {
		Type string `json:"type"` // "agent_message" | "command_execution" | …
		Text string `json:"text"`
	} `json:"item"`
}

// parseCodexStreamLine lifts chat items + the thread id out of one codex
// JSONL line. threadID is non-empty only on thread.started (the caller
// stashes it to `codex exec resume` the next turn). ok is true when events
// carries a renderable chat event. Non-message items (turn.*, tool items
// not yet mapped) and malformed lines return ok=false.
func parseCodexStreamLine(line []byte) (events []ClaudeChatEvent, threadID string, ok bool) {
	line = bytes.TrimSpace(line)
	if len(line) == 0 {
		return nil, "", false
	}
	var ev codexStreamEvent
	if err := json.Unmarshal(line, &ev); err != nil {
		return nil, "", false
	}
	switch ev.Type {
	case "thread.started":
		return nil, ev.ThreadID, false
	case "item.completed":
		if ev.Item.Type == "agent_message" && strings.TrimSpace(ev.Item.Text) != "" {
			return []ClaudeChatEvent{{Role: "assistant", Text: ev.Item.Text}}, "", true
		}
	}
	return nil, "", false
}
