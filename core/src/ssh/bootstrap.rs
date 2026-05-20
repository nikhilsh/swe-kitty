//! Bootstrap-output parser for `scripts/remote-bootstrap.sh`.
//!
//! The script's stdout contract:
//!   - "OK port=<int> token=<bearer> reused=<bool>"
//!   - "ERR <code> <message>"
//!
//! Keeping the parser here (separate from the russh exec plumbing in
//! `mod.rs`) means the parse logic stays unit-testable without spinning
//! up an SSH server. Wire-level exec is integration-tested elsewhere.

use super::SshError;

/// Successful parse of the script's stdout "OK …" line.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedBootstrap {
    pub port: u16,
    pub token: String,
    pub reused: bool,
}

/// Parse the captured stdout (everything the script printed) into either
/// a [`ParsedBootstrap`] or an [`SshError`]. ERR lines win over OK lines
/// so a script that printed status + then errored doesn't get treated
/// as success.
pub fn parse_output(stdout: &str) -> Result<ParsedBootstrap, SshError> {
    let mut err_line: Option<&str> = None;
    let mut ok_line: Option<&str> = None;
    for raw in stdout.lines() {
        let line = raw.trim();
        if let Some(rest) = line.strip_prefix("ERR ") {
            err_line = Some(rest);
        } else if let Some(rest) = line.strip_prefix("OK ") {
            ok_line = Some(rest);
        }
    }

    if let Some(err) = err_line {
        let mut parts = err.splitn(2, ' ');
        let code = parts
            .next()
            .and_then(|c| c.parse::<i32>().ok())
            .unwrap_or(1);
        let msg = parts.next().unwrap_or("").to_string();
        return Err(SshError::from_bootstrap_exit(code, msg));
    }

    let ok = ok_line.ok_or_else(|| {
        SshError::BootstrapParse(format!(
            "no OK/ERR line in remote stdout (got {} bytes)",
            stdout.len()
        ))
    })?;

    let mut port: Option<u16> = None;
    let mut token: Option<String> = None;
    let mut reused: Option<bool> = None;
    for tok in ok.split_ascii_whitespace() {
        if let Some(v) = tok.strip_prefix("port=") {
            port = v.parse().ok();
        } else if let Some(v) = tok.strip_prefix("token=") {
            token = Some(v.to_string());
        } else if let Some(v) = tok.strip_prefix("reused=") {
            reused = match v {
                "true" => Some(true),
                "false" => Some(false),
                _ => None,
            };
        }
    }

    let port = port.ok_or_else(|| SshError::BootstrapParse("OK line missing port=".into()))?;
    let token = token.ok_or_else(|| SshError::BootstrapParse("OK line missing token=".into()))?;
    let reused =
        reused.ok_or_else(|| SshError::BootstrapParse("OK line missing reused=".into()))?;

    if token.len() < 16 {
        return Err(SshError::BootstrapParse(format!(
            "token length {} below 16-char minimum (harness will reject)",
            token.len()
        )));
    }

    Ok(ParsedBootstrap {
        port,
        token,
        reused,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_ok_line() {
        let out = "noise on stderr ignored\n\
                   OK port=1977 token=this-is-a-pre-allocated-token-1234 reused=false\n";
        let parsed = parse_output(out).unwrap();
        assert_eq!(parsed.port, 1977);
        assert_eq!(parsed.token, "this-is-a-pre-allocated-token-1234");
        assert!(!parsed.reused);
    }

    #[test]
    fn parse_reuse_path() {
        let out = "OK port=11977 token=existing-token-abcdef-9876543210 reused=true\n";
        let parsed = parse_output(out).unwrap();
        assert_eq!(parsed.port, 11977);
        assert!(parsed.reused);
    }

    #[test]
    fn err_line_wins_over_ok_line() {
        let out = "OK port=1977 token=bogus reused=false\nERR 11 docker not installed\n";
        match parse_output(out).unwrap_err() {
            SshError::DockerMissing => {}
            other => panic!("expected DockerMissing, got {other:?}"),
        }
    }

    #[test]
    fn err_port_conflict_includes_port() {
        let out = "ERR 14 host port 1977 already in use by another process\n";
        match parse_output(out).unwrap_err() {
            SshError::PortConflict(p) => assert_eq!(p, 1977),
            other => panic!("expected PortConflict, got {other:?}"),
        }
    }

    #[test]
    fn missing_field_reports_parse_error() {
        let out = "OK port=1977 token=abc\n"; // missing reused=
        match parse_output(out).unwrap_err() {
            SshError::BootstrapParse(msg) => assert!(msg.contains("reused")),
            other => panic!("expected BootstrapParse, got {other:?}"),
        }
    }

    #[test]
    fn short_token_rejected_at_parse_time() {
        let out = "OK port=1977 token=tiny reused=false\n";
        match parse_output(out).unwrap_err() {
            SshError::BootstrapParse(msg) => assert!(msg.contains("16-char minimum")),
            other => panic!("expected BootstrapParse, got {other:?}"),
        }
    }

    #[test]
    fn empty_stdout_reports_parse_error() {
        match parse_output("").unwrap_err() {
            SshError::BootstrapParse(msg) => assert!(msg.contains("no OK/ERR line")),
            other => panic!("expected BootstrapParse, got {other:?}"),
        }
    }

    #[test]
    fn malformed_err_code_falls_back_to_exit_code() {
        let out = "ERR not-a-number something broke\n";
        match parse_output(out).unwrap_err() {
            SshError::BootstrapExitCode { code, .. } => assert_eq!(code, 1),
            other => panic!("expected BootstrapExitCode, got {other:?}"),
        }
    }
}
