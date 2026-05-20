#!/usr/bin/env node
// build.mjs — static-site generator for swe-kitty.
//
// Replaces the prior Next.js setup. The site is one HTML page that's
// just download links + current-release info; React/Next added 87KB
// of bundle for nothing visible.
//
// Output: website/out/{index.html, manifest.plist, .deploy.yaml}.
// `fyra push` from website/out/ ships it.

import { mkdir, writeFile, copyFile, access } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.join(__dirname, "out");
const publicDir = path.join(__dirname, "public");

const repo = process.env.GITHUB_REPO || "nikhilsh/swe-kitty";
const siteOrigin = process.env.SITE_ORIGIN || "https://swekitty.kaopeh.com";

const headers = {
    "User-Agent": "swe-kitty-website-build",
    Accept: "application/vnd.github+json",
};
const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
if (token) headers.Authorization = `Bearer ${token}`;

async function fetchLatestRelease() {
    const res = await fetch(`https://api.github.com/repos/${repo}/releases?per_page=20`, { headers });
    if (!res.ok) throw new Error(`github releases fetch: ${res.status}`);
    const releases = await res.json();
    if (!Array.isArray(releases) || releases.length === 0) throw new Error("no releases");

    releases.sort((a, b) => new Date(b.published_at) - new Date(a.published_at));

    const isPublished = (r) => !r.draft && !r.prerelease;
    const hasIpa = (r) => (r.assets || []).some((a) => a.name === "SweKitty.ipa");
    const r =
        releases.find((x) => isPublished(x) && hasIpa(x)) ||
        releases.find((x) => !x.draft && hasIpa(x)) ||
        releases.find(isPublished) ||
        releases.find((x) => !x.draft) ||
        releases[0];

    const assets = r.assets || [];
    return {
        tagName: r.tag_name,
        releaseName: r.name,
        releaseUrl: r.html_url,
        publishedAt: r.published_at,
        ipa: assets.find((a) => a.name === "SweKitty.ipa"),
        apk: assets.find((a) => a.name.endsWith(".apk")),
    };
}

function manifestPlist(ipa, tag) {
    return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>${ipa.browser_download_url}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>sh.nikhil.swekitty</string>
        <key>bundle-version</key>
        <string>${tag}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>SweKitty</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
`;
}

function htmlPage({ tagName, publishedAt, releaseUrl, ipa, apk, manifestUrl, otaInstallUrl }) {
    const repoUrl = `https://github.com/${repo}`;
    const docsUrl = `${repoUrl}/tree/main/docs`;
    const installScriptUrl = `${repoUrl}/releases/download/${tagName}/install.sh`;

    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>SweKitty</title>
<meta name="description" content="Mobile harness for Claude Code + Codex sessions.">
<style>
  :root {
    color-scheme: light dark;
    --bg: #fafafa;
    --fg: #1a1a1a;
    --muted: #6b6b6b;
    --card: #f2f2f7;
    --border: #d1d1d6;
    --accent: #00a86b;
    --accent-text: #fff;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #0c0e12;
      --fg: #fff;
      --muted: #888;
      --card: #1a1a1a;
      --border: #333;
      --accent: #34c759;
      --accent-text: #0d0d0d;
    }
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: var(--bg); color: var(--fg); }
  body {
    font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
  }
  main {
    max-width: 540px;
    margin: 0 auto;
    padding: 56px 20px 24px;
    flex: 1;
  }
  h1 { font-size: 32px; margin: 0 0 6px; letter-spacing: -0.02em; }
  .tagline { color: var(--muted); margin: 0 0 32px; font-size: 15px; }
  .release {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 14px 16px;
    margin-bottom: 20px;
    font-size: 14px;
    color: var(--muted);
  }
  .release strong { color: var(--fg); font-weight: 600; }
  .release-meta { display: block; margin-top: 4px; font-size: 13px; }
  .actions { display: flex; flex-direction: column; gap: 10px; margin-bottom: 28px; }
  a.btn {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 14px 16px;
    border-radius: 12px;
    border: 1px solid var(--border);
    background: var(--card);
    color: var(--fg);
    text-decoration: none;
    font-weight: 500;
    font-size: 15px;
  }
  a.btn:hover { border-color: var(--accent); }
  a.btn.primary { background: var(--accent); color: var(--accent-text); border-color: var(--accent); }
  a.btn .arrow { margin-left: auto; opacity: 0.55; }
  a.btn small { display: block; font-weight: 400; font-size: 12px; opacity: 0.75; }
  pre {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 12px 14px;
    font: 13px/1.5 ui-monospace, "SF Mono", Menlo, monospace;
    overflow-x: auto;
    margin: 0 0 28px;
  }
  h2 {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: var(--muted);
    margin: 0 0 10px;
    font-weight: 600;
  }
  footer {
    text-align: center;
    padding: 24px 20px 32px;
    font-size: 13px;
    color: var(--muted);
  }
  footer a { color: var(--muted); margin: 0 6px; }
</style>
</head>
<body>
<main>
  <h1>SweKitty</h1>
  <p class="tagline">Mobile harness for Claude Code &amp; Codex.</p>

  <div class="release">
    Latest: <strong>${tagName}</strong>
    <span class="release-meta" id="release-meta" data-published="${publishedAt}">
      published <time datetime="${publishedAt}">${publishedAt}</time>
    </span>
  </div>

  <h2>Install</h2>
  <div class="actions">
    ${ipa ? `<a class="btn primary" href="${otaInstallUrl}">
      Install on iPhone / iPad
      <small>OTA install via this site</small>
      <span class="arrow">→</span>
    </a>` : ""}
    ${ipa ? `<a class="btn" href="${ipa.browser_download_url}">
      Download IPA
      <small>Sideload via AltStore / Sideloadly</small>
      <span class="arrow">↓</span>
    </a>` : ""}
    ${apk ? `<a class="btn" href="${apk.browser_download_url}">
      Download APK
      <small>Android sideload</small>
      <span class="arrow">↓</span>
    </a>` : ""}
  </div>

  <h2>Run the harness</h2>
  <pre>curl -sSL ${installScriptUrl} | sudo sh -s -- --service --addr :1977 --local</pre>

  <h2>Links</h2>
  <div class="actions">
    <a class="btn" href="${releaseUrl}">Release notes <span class="arrow">↗</span></a>
    <a class="btn" href="${repoUrl}">GitHub <span class="arrow">↗</span></a>
    <a class="btn" href="${docsUrl}">Docs <span class="arrow">↗</span></a>
  </div>
</main>

<footer>
  <a href="${repoUrl}">github</a>·<a href="${docsUrl}">docs</a>·<a href="${repoUrl}/issues">issues</a>
</footer>

<script>
  // Render the publish timestamp in the visitor's local timezone.
  // The server's UTC clock would just echo back UTC; only the browser
  // knows the user's actual zone.
  (function () {
    var el = document.getElementById('release-meta');
    if (!el) return;
    var iso = el.getAttribute('data-published');
    if (!iso) return;
    var d = new Date(iso);
    if (isNaN(d)) return;
    var fmt = d.toLocaleString('en-US', {
      year: 'numeric', month: 'short', day: 'numeric',
      hour: 'numeric', minute: '2-digit', timeZoneName: 'short',
    });
    el.innerHTML = 'published <time datetime="' + iso + '">' + fmt + '</time>';
  })();
</script>
</body>
</html>
`;
}

async function build() {
    const r = await fetchLatestRelease();
    const manifestUrl = `${siteOrigin}/manifest.plist`;
    const otaInstallUrl = `itms-services://?action=download-manifest&url=${encodeURIComponent(manifestUrl)}`;

    await mkdir(outDir, { recursive: true });

    await writeFile(
        path.join(outDir, "index.html"),
        htmlPage({ ...r, manifestUrl, otaInstallUrl })
    );
    if (r.ipa) {
        await writeFile(path.join(outDir, "manifest.plist"), manifestPlist(r.ipa, r.tagName));
    }

    // Copy any static files from public/ if present.
    if (existsSync(publicDir)) {
        const { readdir } = await import("node:fs/promises");
        const items = await readdir(publicDir);
        for (const name of items) {
            await copyFile(path.join(publicDir, name), path.join(outDir, name));
        }
    }

    // Copy the deploy descriptor so `cd out && fyra push` works.
    const deployYaml = path.join(__dirname, ".deploy.yaml");
    if (existsSync(deployYaml)) {
        await copyFile(deployYaml, path.join(outDir, ".deploy.yaml"));
    }

    console.log(`wrote ${path.relative(process.cwd(), outDir)}/index.html · release ${r.tagName}`);
}

build().catch((err) => {
    console.error("build failed:", err.message);
    process.exit(1);
});
