//go:build ignore
// +build ignore

package session

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/nikhilsh/swe-kitty/harness/internal/agents"
	"github.com/nikhilsh/swe-kitty/harness/internal/memory"
)

func (s *Session) startBackgroundLoops() {
	go s.checkpointLoop()
	go s.watchdogLoop()
}

func (s *Session) checkpointLoop() {
	ticker := time.NewTicker(s.checkpointEvery)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			_ = s.Checkpoint("ticker")
		case <-s.closed:
			return
		}
	}
}

func (s *Session) Checkpoint(reason string) error {
	s.checkpointMu.Lock()
	defer s.checkpointMu.Unlock()

	snapshot := s.Snapshot()
	if err := atomicWriteFile(s.scrollbackPath, snapshot); err != nil {
		s.setHealth("warning", "stalled")
		return err
	}
	now := time.Now().UTC()
	if _, err := memory.Checkpoint(s.repoRoot, memory.CheckpointOptions{
		SessionData: memory.SessionData{
			SessionID:      s.ID,
			WorktreePath:   s.worktreeDir,
			Branch:         s.defaultBranchName(),
			TaskID:         "session",
			CurrentAgent:   s.Assistant,
			CreatedAt:      now,
			CheckpointAt:   now,
			TaskBriefPath:  filepath.ToSlash(filepath.Join(".swe-kitty", "tasks")),
			TaskSummary:    "Long-running session memory scaffold.",
			LastCompleted:  "",
			CurrentlyDoing: "Running agent session",
			NextStep:       "Continue session work",
			ScrollbackTail: tailText(snapshot, 40),
		},
		Reason: reason,
	}); err != nil {
		s.setHealth("warning", "stalled")
		return err
	}
	s.mu.Lock()
	s.lastCheckpoint = now
	s.phase = "running"
	s.mu.Unlock()
	if err := s.persistMetadata(); err != nil {
		return err
	}
	_ = s.autoWIP(now)
	s.emitStatus("running", "")
	_ = reason
	return nil
}

func (s *Session) autoWIP(ts time.Time) error {
	status := exec.Command("git", "-C", s.workspaceDir, "status", "--porcelain")
	out, err := status.Output()
	if err != nil {
		return nil
	}
	if len(bytes.TrimSpace(out)) == 0 {
		return nil
	}
	add := exec.Command("git", "-C", s.workspaceDir, "add", "-A")
	if err := add.Run(); err != nil {
		return nil
	}
	stash := exec.Command(
		"git",
		"-C",
		s.workspaceDir,
		"stash",
		"push",
		"--include-untracked",
		"-m",
		fmt.Sprintf("checkpoint:%s", ts.Format(time.RFC3339Nano)),
	)
	_ = stash.Run()
	return nil
}

func (s *Session) prepareFilesystem() error {
	dirs := []string{
		s.sessionDir,
		s.worktreeDir,
		filepath.Dir(s.memoryPath),
		filepath.Dir(s.handoffPath),
	}
	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}
	if err := s.ensureWorktree(); err != nil {
		return err
	}
	now := time.Now().UTC()
	data := memory.SessionData{
		SessionID:      s.ID,
		WorktreePath:   s.worktreeDir,
		Branch:         s.defaultBranchName(),
		TaskID:         "session",
		CurrentAgent:   s.Assistant,
		CreatedAt:      now,
		CheckpointAt:   now,
		TaskBriefPath:  filepath.ToSlash(filepath.Join(".swe-kitty", "tasks")),
		TaskSummary:    "Long-running session memory scaffold.",
		LastCompleted:  "",
		CurrentlyDoing: "Bootstrapping session memory",
		NextStep:       "Wait for agent work",
		ScrollbackTail: "",
	}
	if err := memory.Init(s.repoRoot); err != nil {
		return err
	}
	if !fileExists(s.memoryPath) {
		if _, err := memory.Checkpoint(s.repoRoot, memory.CheckpointOptions{SessionData: data}); err != nil {
			return err
		}
	}
	if !fileExists(s.handoffPath) {
		if content, err := os.ReadFile(s.memoryPath); err == nil {
			if err := atomicWriteFile(s.handoffPath, content); err != nil {
				return err
			}
		}
	}
	return nil
}

func (s *Session) commandDir(adapter agents.Adapter) string {
	if adapter.Workdir != "" {
		if dirExists(adapter.Workdir) {
			return adapter.Workdir
		}
		if dirExists(filepath.Join(s.repoRoot, adapter.Workdir)) {
			return filepath.Join(s.repoRoot, adapter.Workdir)
		}
	}
	return s.worktreeDir
}

func (s *Session) commandEnv(extra map[string]string) []string {
	env := append(os.Environ(),
		"TERM=xterm-256color",
		"PS1=$ ",
		"SESSION_UUID="+s.ID,
		"AGENT_NAME="+s.Assistant,
		"WORKTREE_BRANCH="+s.defaultBranchName(),
		"KITTY_HANDOFF_PATH="+s.handoffPath,
		"KITTY_HANDOFF_OUT_PATH="+s.handoffOutPath,
	)
	for _, key := range s.adapter.EnvPassthrough {
		if value, ok := os.LookupEnv(key); ok {
			env = append(env, key+"="+value)
		}
	}
	for k, v := range extra {
		env = append(env, k+"="+v)
	}
	return env
}

func (s *Session) restoreSnapshot(snapshot []byte) {
	for _, b := range snapshot {
		s.ring[s.ringPos] = b
		s.ringPos++
		if s.ringPos == ringSize {
			s.ringPos = 0
			s.ringFull = true
		}
	}
}

func (s *Session) loadHandoffHTML() string {
	content, err := os.ReadFile(s.handoffPath)
	if err != nil {
		return ""
	}
	return string(content)
}

func (s *Session) runHook(hook string, extra map[string]string) error {
	if strings.TrimSpace(hook) == "" {
		return nil
	}
	cmd := exec.Command("bash", "-lc", hook)
	cmd.Dir = s.workspaceDir
	cmd.Env = s.commandEnv(extra)
	return cmd.Run()
}

func tailText(snapshot []byte, maxLines int) string {
	text := string(snapshot)
	lines := strings.Split(text, "\n")
	if len(lines) <= maxLines {
		return text
	}
	return strings.Join(lines[len(lines)-maxLines:], "\n")
}
