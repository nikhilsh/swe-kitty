package push

import (
	"context"
	"errors"
	"testing"
)

// recordingSender records each Send call and can be told to fail a
// specific token (with an arbitrary error, including ErrTokenGone).
type recordingSender struct {
	sent     []DeviceToken
	failWith map[string]error // token -> error to return
}

func (s *recordingSender) Send(_ context.Context, token DeviceToken, _ Payload) error {
	s.sent = append(s.sent, token)
	if s.failWith != nil {
		if err, ok := s.failWith[token.Token]; ok {
			return err
		}
	}
	return nil
}

func TestDispatcherFansOutToAllPlatforms(t *testing.T) {
	reg := NewRegistry()
	reg.Register("alice", tok(PlatformAPNs, "a1"))
	reg.Register("alice", tok(PlatformFCM, "f1"))
	apns := &recordingSender{}
	fcm := &recordingSender{}
	d := NewDispatcher(reg, map[Platform]Sender{PlatformAPNs: apns, PlatformFCM: fcm})

	if err := d.Notify(context.Background(), "alice", Payload{Title: "t", Body: "b"}); err != nil {
		t.Fatalf("Notify: %v", err)
	}
	if len(apns.sent) != 1 || apns.sent[0].Token != "a1" {
		t.Fatalf("apns sent = %+v, want [a1]", apns.sent)
	}
	if len(fcm.sent) != 1 || fcm.sent[0].Token != "f1" {
		t.Fatalf("fcm sent = %+v, want [f1]", fcm.sent)
	}
}

func TestDispatcherPrunesGoneTokens(t *testing.T) {
	reg := NewRegistry()
	reg.Register("alice", tok(PlatformAPNs, "good"))
	reg.Register("alice", tok(PlatformAPNs, "dead"))
	apns := &recordingSender{failWith: map[string]error{"dead": ErrTokenGone}}
	d := NewDispatcher(reg, map[Platform]Sender{PlatformAPNs: apns})

	// ErrTokenGone is not surfaced as an error — it's handled by pruning.
	if err := d.Notify(context.Background(), "alice", Payload{}); err != nil {
		t.Fatalf("Notify should not error on ErrTokenGone, got %v", err)
	}
	left := reg.TokensFor("alice")
	if len(left) != 1 || left[0].Token != "good" {
		t.Fatalf("after prune, tokens = %+v, want [good]", left)
	}
}

func TestDispatcherSkipsPlatformWithoutSender(t *testing.T) {
	reg := NewRegistry()
	reg.Register("alice", tok(PlatformAPNs, "a1"))
	reg.Register("alice", tok(PlatformFCM, "f1"))
	// Only an APNs sender configured; FCM has none.
	apns := &recordingSender{}
	d := NewDispatcher(reg, map[Platform]Sender{PlatformAPNs: apns})

	if err := d.Notify(context.Background(), "alice", Payload{}); err != nil {
		t.Fatalf("Notify: %v", err)
	}
	if len(apns.sent) != 1 {
		t.Fatalf("apns sent = %d, want 1", len(apns.sent))
	}
	// The FCM token is left registered (not pruned) for when a sender lands.
	if n := len(reg.TokensFor("alice")); n != 2 {
		t.Fatalf("tokens = %d, want 2 (fcm kept)", n)
	}
}

func TestDispatcherJoinsTransientErrors(t *testing.T) {
	reg := NewRegistry()
	reg.Register("alice", tok(PlatformAPNs, "a1"))
	boom := errors.New("apns 503")
	apns := &recordingSender{failWith: map[string]error{"a1": boom}}
	d := NewDispatcher(reg, map[Platform]Sender{PlatformAPNs: apns})

	err := d.Notify(context.Background(), "alice", Payload{})
	if err == nil || !errors.Is(err, boom) {
		t.Fatalf("expected transient error surfaced, got %v", err)
	}
	// Transient failure does NOT prune the token.
	if n := len(reg.TokensFor("alice")); n != 1 {
		t.Fatalf("token should be kept on transient error, got %d", n)
	}
}

// Dispatcher must satisfy the Notifier interface.
var _ Notifier = (*Dispatcher)(nil)
