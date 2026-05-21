// terminal.js — xterm.js bootstrap for SweKitty iOS WKWebView host.
// Communicates with Swift via webkit.messageHandlers.term:
//   { type: "ready" }                     emitted once after term.open()
//   { type: "input", data: "<utf8>" }    keystroke from xterm.onData
//   { type: "resize", cols, rows }       fit/resize from xterm.onResize
// Swift drives the terminal via these globals:
//   window.feedBytes(b64)   — base64-decoded UTF-8 bytes are written into xterm
//   window.serializeState() — returns full ANSI snapshot via SerializeAddon
//   window.reset()          — clears terminal (used on snapshot replace)
(function () {
  "use strict";

  function post(msg) {
    try {
      window.webkit.messageHandlers.term.postMessage(msg);
    } catch (e) {
      // No bridge (e.g. opened outside WKWebView) — drop silently.
    }
  }

  var term = new Terminal({
    fontFamily: "Menlo, monospace",
    fontSize: 13,
    theme: { background: "#0c0c0c", foreground: "#e8e8e8" },
    allowProposedApi: true,
    convertEol: false,
    scrollback: 10000,
    cursorBlink: false,
  });

  var fit = new FitAddon.FitAddon();
  term.loadAddon(fit);

  var serializer = new SerializeAddon.SerializeAddon();
  term.loadAddon(serializer);

  try {
    term.loadAddon(new WebglAddon.WebglAddon());
  } catch (e) {
    // WebGL unavailable — xterm falls back to the DOM renderer silently.
  }

  // We defer term.open() until window.load so fit.fit() has accurate
  // layout dimensions. Posting the fitted size BEFORE we accept any
  // bytes from Swift means the harness can ship its first snapshot
  // reflowed to our real viewport — fixing the size-mismatched wrap
  // that plain xterm-on-the-client can't undo.
  function boot() {
    term.open(document.getElementById("term"));
    try { fit.fit(); } catch (e) { /* ignore */ }

    // Belt-and-braces: emit a resize event with the fitted dimensions
    // explicitly. xterm's own onResize fires when dimensions change
    // from the constructor defaults, but we want to be sure Swift sees
    // them even if fit happened to produce the same shape.
    try {
      var d = fit.proposeDimensions();
      if (d && d.cols && d.rows) {
        post({ type: "resize", cols: d.cols, rows: d.rows });
      } else {
        post({ type: "resize", cols: term.cols, rows: term.rows });
      }
    } catch (e) {
      post({ type: "resize", cols: term.cols, rows: term.rows });
    }

    term.onData(function (d) {
      post({ type: "input", data: d });
    });

    term.onResize(function (sz) {
      post({ type: "resize", cols: sz.cols, rows: sz.rows });
    });

    window.addEventListener("resize", function () {
      try { fit.fit(); } catch (e) { /* ignore */ }
    });

    window.feedBytes = function (b64) {
      var bin = atob(b64);
      var arr = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
      term.write(arr);
    };

    window.serializeState = function () {
      return serializer.serialize();
    };

    window.reset = function () {
      term.reset();
    };

    // Tell Swift we are ready to receive bytes.
    post({ type: "ready" });
  }

  if (document.readyState === "complete") {
    boot();
  } else {
    window.addEventListener("load", boot);
  }
})();
