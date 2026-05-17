//go:build ignore
// +build ignore

package session

import (
	"os"
	"os/exec"
	"syscall"
	"time"

	"github.com/creack/pty"

	"github.com/nikhilsh/swe-kitty/harness/internal/agents"
	"github.com/nikhilsh/swe-kitty/harness/internal/memory"
)

func (s *Session) switchToAdapter(adapter agents.Adapter) error {
	oldAssistant := s.Assistant
	s.emitStatus("swapping", "")
	_ = s.Checkpoint("switch_agent")
	_ = os.Remove(s.handoffOutPath)
	if s.cmd != nil && s.cmd.Process != nil {
		_ = s.cmd.Process.Signal(syscall.SIGUSR1)
		waitUntil := time.Now().Add(s.handoffTimeout)
		for time.Now().Before(waitUntil) {
			if fileExists(s.handoffOutPath) {
				break
			}
			time.Sleep(25 * time.Millisecond)
		}
	}
	if fileExists(s.handoffOutPath) {
		_, _ = memory.Handoff(s.repoRoot, memory.HandoffOptions{
			SessionID:   s.ID,
			From:        oldAssistant,
			To:          adapter.Name,
			Reason:      "switch_agent",
			HandoffPath: s.handoffOutPath,
		})
	}
	_ = s.runHook(s.hooks.OnSwap, map[string]string{
		"FROM_AGENT": oldAssistant,
		"TO_AGENT":   adapter.Name,
	})
	cmd := exec.Command(adapter.Command[0], append(adapter.Command[1:], adapter.Args...)...)
	cmd.Dir = s.commandDir(adapter)
	cmd.Env = s.commandEnv(map[string]string{
		"FROM_AGENT": oldAssistant,
		"TO_AGENT":   adapter.Name,
	})
	f, err := pty.Start(cmd)
	if err != nil {
		return err
	}
	_ = pty.Setsize(f, &pty.Winsize{Rows: s.rows, Cols: s.cols})
	oldPTY := s.pty
	oldCmd := s.cmd
	s.mu.Lock()
	s.adapter = adapter
	s.Assistant = adapter.Name
	s.pty = f
	s.cmd = cmd
	s.hooks = adapter.Hooks
	s.workspaceDir = s.commandDir(adapter)
	s.phase = "running"
	s.health = "healthy"
	s.mu.Unlock()
	_ = s.persistMetadata()
	if oldPTY != nil {
		_ = oldPTY.Close()
	}
	if oldCmd != nil && oldCmd.Process != nil {
		_ = oldCmd.Process.Kill()
		_, _ = oldCmd.Process.Wait()
	}
	if content, err := os.ReadFile(s.memoryPath); err == nil {
		_ = atomicWriteFile(s.handoffPath, content)
	}
	go s.drain(f)
	s.emitStatus("running", "healthy")
	return nil
}
