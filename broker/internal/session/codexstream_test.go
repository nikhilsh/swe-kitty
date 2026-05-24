package session

import (
	"bufio"
	"os"
	"testing"
)

// TestParseCodexStreamLineFixture runs the parser over a real
// `codex exec --json` capture: thread.started → turn.started →
// item.completed(agent_message "pong") → turn.completed. Only the
// agent_message should surface; thread.started yields the resume id.
func TestParseCodexStreamLineFixture(t *testing.T) {
	f, err := os.Open("testdata/codex-exec-sample.jsonl")
	if err != nil {
		t.Fatalf("open fixture: %v", err)
	}
	defer f.Close()

	var texts []string
	var threadID string
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		evs, tid, ok := parseCodexStreamLine(sc.Bytes())
		if tid != "" {
			threadID = tid
		}
		if !ok {
			continue
		}
		for _, e := range evs {
			if e.Text != "" {
				texts = append(texts, e.Text)
			}
		}
	}
	if err := sc.Err(); err != nil {
		t.Fatalf("scan: %v", err)
	}
	if threadID == "" {
		t.Fatalf("expected a thread id from thread.started, got none")
	}
	if len(texts) != 1 || texts[0] != "pong" {
		t.Fatalf("expected one assistant text \"pong\", got %v", texts)
	}
}

func TestParseCodexStreamLineCases(t *testing.T) {
	cases := []struct {
		name, line, wantText, wantThread string
		wantOK                           bool
	}{
		{
			name:     "agent_message",
			line:     `{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"hello"}}`,
			wantText: "hello", wantOK: true,
		},
		{
			name:       "thread.started yields id, no event",
			line:       `{"type":"thread.started","thread_id":"abc-123"}`,
			wantThread: "abc-123", wantOK: false,
		},
		{name: "turn.started ignored", line: `{"type":"turn.started"}`, wantOK: false},
		{name: "turn.completed ignored", line: `{"type":"turn.completed"}`, wantOK: false},
		{name: "non-message item ignored", line: `{"type":"item.completed","item":{"type":"command_execution","text":""}}`, wantOK: false},
		{name: "empty agent_message dropped", line: `{"type":"item.completed","item":{"type":"agent_message","text":"  "}}`, wantOK: false},
		{name: "malformed ignored", line: `{nope`, wantOK: false},
		{name: "blank ignored", line: ``, wantOK: false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			evs, tid, ok := parseCodexStreamLine([]byte(tc.line))
			if ok != tc.wantOK {
				t.Fatalf("ok=%v want %v (evs=%+v tid=%q)", ok, tc.wantOK, evs, tid)
			}
			if tid != tc.wantThread {
				t.Fatalf("threadID=%q want %q", tid, tc.wantThread)
			}
			if tc.wantText != "" && (len(evs) != 1 || evs[0].Text != tc.wantText) {
				t.Fatalf("want text %q, got %+v", tc.wantText, evs)
			}
		})
	}
}
