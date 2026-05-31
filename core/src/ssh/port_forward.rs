//! Bidirectional TCP↔SSH-channel proxy.
//!
//! Inspired by upstream's same-named file (the bidi-copy pattern is the
//! same anywhere you tunnel a TCP socket through an SSH session). The
//! mobile-side WebSocket transport connects to a local TCP listener on
//! `127.0.0.1:<local_port>`; every accept is paired with a russh
//! `direct-tcpip` channel to `127.0.0.1:<remote_port>` on the SSH peer.
//!
//! This file is deliberately framework-light: no shared state, no
//! cancellation registry — the SSH session's lifetime owns the listener
//! lifetime, and dropping the listener cleans up.

use std::net::SocketAddr;

use russh::client::Msg;
use russh::Channel;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};

use super::SshError;

/// Spawn the bidi copy for a single accepted connection. Returns once
/// either direction's TCP half closes.
pub(crate) async fn proxy_connection(
    local: TcpStream,
    mut ssh_channel: Channel<Msg>,
    peer: SocketAddr,
    local_port: u16,
    remote_port: u16,
) {
    let mut ssh_writer = ssh_channel.make_writer();
    let (mut local_read, mut local_write) = local.into_split();

    // local → remote (driven by a spawned task because Channel::wait
    // takes `&mut self` and we need the local-read half on a separate
    // future).
    let l2r = tokio::spawn(async move {
        let mut buf = vec![0u8; 32 * 1024];
        loop {
            match local_read.read(&mut buf).await {
                Ok(0) => break,
                Ok(n) => {
                    if ssh_writer.write_all(&buf[..n]).await.is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
        let _ = ssh_writer.shutdown().await;
    });

    // remote → local on this task. Channel::wait() reads off the SSH
    // multiplexer.
    while let Some(msg) = ssh_channel.wait().await {
        match msg {
            russh::ChannelMsg::Data { ref data } if local_write.write_all(data).await.is_err() => {
                break
            }
            russh::ChannelMsg::Eof | russh::ChannelMsg::Close => break,
            _ => {}
        }
    }
    let _ = local_write.shutdown().await;
    let _ = l2r.await;
    let _ = (peer, local_port, remote_port); // touched for future trace logs
}

/// Pick a free localhost TCP port by binding to :0 and reading back the
/// kernel-allocated port. Returns the bound listener so the caller can
/// keep it (the port stays held until the listener is dropped).
pub(crate) async fn bind_random_local() -> Result<(TcpListener, u16), SshError> {
    let l = TcpListener::bind(("127.0.0.1", 0))
        .await
        .map_err(|e| SshError::PortForward(format!("bind 127.0.0.1:0: {e}")))?;
    let port = l
        .local_addr()
        .map_err(|e| SshError::PortForward(format!("local_addr: {e}")))?
        .port();
    Ok((l, port))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn bind_random_local_returns_listening_port() {
        let (listener, port) = bind_random_local().await.unwrap();
        assert!(port > 0);
        // The port should actually be reachable while the listener is
        // alive.
        let probe = TcpStream::connect(("127.0.0.1", port)).await;
        assert!(probe.is_ok(), "expected to dial the bound port: {probe:?}");
        drop(listener);
    }
}
