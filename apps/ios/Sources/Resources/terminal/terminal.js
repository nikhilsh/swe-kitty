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

  term.open(document.getElementById("term"));
  try { fit.fit(); } catch (e) { /* ignore */ }

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
})();
