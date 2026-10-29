<div align="center">
  <img src="assets/logo.svg" alt="Ajar Logo" width="48" height="80" />
  <h1>Ajar</h1>
  <p><strong>Localhost Port Manager for the macOS Menu Bar &amp; CLI</strong></p>
  <p><em>See which project owns every localhost port, what each port is for, and close the ones you no longer need — safely.</em></p>

  <p>
    <a href="https://boyongjiong.github.io/ajar/"><img src="https://img.shields.io/badge/website-ajar-211811?style=flat-square" alt="Website" /></a>
    <img src="https://img.shields.io/badge/macOS-14.0%2B-555555?style=flat-square" alt="macOS 14+" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-555555?style=flat-square" alt="License: MIT" /></a>
  </p>

  <p><strong>English</strong> · <a href="README.zh-CN.md">中文</a></p>

  <br />
  <picture>
    <source srcset="assets/preview-dark.png" media="(prefers-color-scheme: dark)">
    <img src="assets/preview.png" alt="Ajar menu bar panel: closable ports first, apps and system services folded away" width="375" />
  </picture>
  <br /><br />
</div>

With several coding agents working in parallel, dev servers, test runners and build daemons keep starting on different ports, and by the end of the day a few are always still running. `lsof` and `kill-port` say a port is in use, but not which project it belongs to or what it does.

**Ajar** sits in the menu bar and shows every listening port, the process and project behind it, and what the port is for. Close the doors that were left ajar — gently.

> Ajar is a fork of [LeftOpen](https://github.com/SonghaiFan/leftopen) by Songhai Fan. See [Credits](#credits).

## Installation

Ajar has no published release yet; build it from source. Requires Xcode (the full app, not only the Command Line Tools) on macOS Sonoma (14.0+), Apple Silicon or Intel.

```bash
git clone https://github.com/boyongjiong/ajar.git
cd ajar
python3 Scripts/dev-app.py run        # build and run a local test app
```

To install your own build:

```bash
AJAR_OUTPUT_DIR=dist/local zsh Scripts/build-app.sh
cp -R dist/local/Ajar.app /Applications/
ln -sf /Applications/Ajar.app/Contents/MacOS/ajar /opt/homebrew/bin/ajar   # optional: CLI
```

Local builds are ad-hoc signed, which is fine on your own Mac. If downloads fail with `CERTIFICATE_VERIFY_FAILED`, run the *Install Certificates* command that ships with python.org Python, or set `SSL_CERT_FILE=/etc/ssl/cert.pem`.

---

## Design & Features

- **Knows whose port it is.** Walks up from the process's working directory to `.git`, `package.json`, `pyproject.toml`, `Cargo.toml` or `go.mod`, or resolves the owning `.app`. Global npm packages, `python -m` modules and standalone services (Redis, Postgres, Ollama…) are named too, so you rarely see a bare `node` or `python`.
- **Real icons, nothing bundled.** Uses the `.app` icon when there is one; otherwise the icon the project or package ships itself (Tauri/Electron app icon, the favicon declared in `index.html`, `public/` conventions); otherwise the favicon served by the local server; otherwise a symbol.
- **Grouped by who started them.** Dev Servers (from a project, terminal, editor or agent), Background Services (launchd: brew services, login items), Apps and System. The group is also how a port is closed for good, and each one says so: SIGTERM for dev servers, `brew services stop …` for services launchd would restart, quitting the app for apps.
- **Closes gently first.** Sends `SIGTERM` and re-checks process identity. If a single-process close still leaves it listening after five seconds, that process is marked and the warning explains that closing it again within two minutes sends `SIGKILL`. The second click or swipe is the deliberate force-close action; existing safety protections and identity checks still apply.
- **Local vs LAN.** Tells apart ports bound to `127.0.0.1` from ones on `0.0.0.0` or a LAN address.
- **Hidden ports.** Hide selected ports from the list, search, menu bar count, and change sounds in **Settings → Ports → Hidden Ports**, or choose **Hide Port** from its context menu. Enter ports with Return or commas, or paste several at once. Each saved port becomes a tag; click its × to show that port again. Services keep running.
- **Appearance.** Choose System, Light or Dark in **Settings → General**, alongside language, login startup and sounds. **Projects** shows the local address service's health.
- **Quiet by default.** Native SwiftUI `MenuBarExtra`. No Dock icon, no telemetry, and no background service unless you opt into fixed addresses. The only request that leaves this Mac is a daily check of the latest GitHub release, which you can turn off in Settings.
- **Fixed project addresses.** Give a dev server a stable `https://myapp.localhost` URL that follows it across port changes, powered by bundled [Portless](https://github.com/vercel-labs/portless). See [below](#fixed-project-addresses).
- **Says what each port is for.** A process with several ports shows each one's role — Spring Actuator, app server, a page by its title, a JSON API, or TCP that doesn't speak HTTP — from two bounded requests on this Mac's own addresses.
- **Names build daemons and tunnels.** Gradle, Kotlin and Maven daemons and sshuttle are shown as themselves instead of the project folder they were started from, and "Close All" leaves them alone.
- **Same engine in the terminal.** The app ships an `ajar` CLI with identical inference and safety rules.

---

## Fixed project addresses

Dev servers move between ports; their address doesn't have to. Ajar bundles [Portless](https://github.com/vercel-labs/portless) 0.15.7 and Node 24.14.0, so there's nothing extra to install.

1. **One-time setup:** Turn on **Settings → Projects → Fixed addresses**. macOS asks for authorization to trust a local CA, install a loopback-only HTTPS service on the selected proxy port (443 by default), and manage exact `/etc/hosts` entries. Only explicit Settings actions ask; project actions and background scans never do.
2. **Per project:** start the project as usual, then click **Enable fixed address** in its port details. It's reachable at `https://myapp.localhost`.

How it behaves:

- **Verified before forwarding.** Ajar checks the project root, executable, working directory, hashed command identity and live listener before following a port change. Ambiguous or unrelated listeners, HTTPS-only upstreams and non-web ports are never forwarded. If the dev server rejects the hostname, the details show why; project files are never edited.
- **Start stopped projects.** Saved projects that aren't running show **Start** when they have a dev script, using Portless's own launcher (free-port allocation, framework arguments, worktree naming). Projects without a dev script can declare one in `.claude/launch.json` (`runtimeExecutable`, `runtimeArgs`, `port`); Ajar runs it through `portless run` without a shell, only when you click **Start**. `portless.json` and the `"portless"` key in `package.json` are read by Portless itself. Ajar never reconstructs commands from process arguments. Projects with neither can right-click their shortcut and choose **Copy Setup Prompt for AI**, then paste it into a coding agent to create `.claude/launch.json`.
- **Leases, not permanent rules.** Mappings for observed services use short leases that expire when Ajar stops scanning and restore on launch. Disabling an address doesn't stop the project. The HTTPS service stays installed across app quits; if port 443 is already taken, Ajar reports it instead of taking over.
- **For agents and scripts:** `ajar url [name|port|path]` prints verified addresses (`--json` for structured output), and `ajar --json` includes `fixedURL` for matching services.

Earlier HTTP addresses keep working; finish the HTTPS upgrade from the same Settings page. Portless (Apache-2.0) and Node ship with their licenses.

**Address settings:** Settings → Projects has a single fixed-address row, with no manual port configuration. Initial setup prefers 443, automatically trying 8443–8462 on conflict within the same authorization. Successful setup remembers the selected port and includes it in opened/copied URLs. Other listeners are never stopped; failures retain copyable diagnostics. Ports are not automatically migrated while Ajar-launched projects run. Turning off removes managed routes but preserves bindings, certificates and the proxy without stopping project servers; stop Ajar-launched projects first.

---

## Why Ajar? (Common Use Cases)

- **Fix "Port already in use" (`EADDRINUSE`)**: When your dev server fails because port 3000, 5173, or 8080 is blocked by a lingering process, Ajar shows you what's running and shuts it down gently—without restarting your terminal or machine.
- **Identify the project, not just a generic `node` or `python` PID**: Tools like `lsof -i` or `kill-port` only report raw PIDs or ambiguous process names. Ajar tracks the working directory and project root (`package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `.git`), giving you full context before taking action.
- **Spot accidental LAN exposure**: See at a glance whether a port is bound strictly to `127.0.0.1` (local only) or `0.0.0.0` (accessible to anyone on your local network/Wi-Fi).
- **Graceful SIGTERM vs. destructive `kill -9`**: Unlike blunt force-killing scripts, Ajar re-verifies PID and start time, shows sibling ports, and issues a standard `SIGTERM` so servers can clean up sockets, flush logs, and exit cleanly.

---

## CLI

Available in the terminal right after installing:

```bash
# List every listening port and its owner (or: ajar list)
ajar

# Explain one port
ajar 3000

# Open http://localhost:3000 in the default browser
ajar open 3000

# Print a project's verified fixed address (e.g. https://myapp.localhost)
ajar url myapp

# Close the process on a port (SIGTERM, asks first)
ajar close 3000

# Structured JSON output
ajar --json
```

Sample output:
```text
AJAR
26 listening ports · 17 processes · 1 projects · 8 LAN-visible

MY PROJECTS (2)
PORT    PID      OWNER          PROCESS    AGE      SCOPE
5173    76344    visdelta       node       2h       LOCAL
         ↳ ~/Documents/visdelta
5511    4999     visdelta       node       27m      LOCAL
         ↳ ~/Documents/visdelta

APPLICATIONS (16)
PORT    PID      OWNER          PROCESS    AGE      SCOPE
5000    696      ControlCenter  Control    3d       LAN
9222    36824    Google Chrome  Chrome     5h       LOCAL

SERVICES (3)
PORT    PID      OWNER          PROCESS    AGE      SCOPE
11434   911      Ollama         ollama     1d       LOCAL

LOCAL = this Mac only · LAN = may be reachable from your local network
```

---

## Development

Maintainers: [one-click releases](docs/releasing.md).

```bash
# Tests
swift test

# Build one replaceable local test app (hidden .build/local-app.noindex)
Scripts/build-app.sh

# Build, run, and remove the test app when it exits
python3 Scripts/dev-app.py run

# Remove a build-only test app
python3 Scripts/dev-app.py clean
```

Local builds use the name **Ajar Test** and a separate bundle identifier. They never install into `/Applications`. Cleanup refuses active app/runtime processes and only removes its managed output. Quit the test app before cleaning. Fixed-address services and other user data are not reset. CI and release packaging continue to set an explicit `AJAR_OUTPUT_DIR`; do not use versioned `dist/` folders for routine local tests.

---

## License

[MIT License](LICENSE)

## Uninstall

For complete removal, use **Ajar → Settings → About → Uninstall Ajar…**. Deleting
the app alone leaves fixed-address services, certificates and settings behind; if it
is already gone, rebuild the app and use its uninstaller. See [complete uninstall](docs/uninstall.md).

## Migrating from LeftOpen

Ajar uses its own identifiers (`io.github.boyongjiong.ajar.*`), so it runs alongside
LeftOpen without touching LeftOpen's services, certificates or `/etc/hosts` entries.
On first launch Ajar copies LeftOpen's preferences (language, appearance, hidden ports,
refresh interval and similar); fixed addresses are set up again in Ajar. To remove
LeftOpen's background service, use LeftOpen's own uninstaller before deleting it.

## Credits

Ajar is a fork of [LeftOpen](https://github.com/SonghaiFan/leftopen), created by
[Songhai Fan](https://github.com/SonghaiFan) and released under the MIT License, which
Ajar keeps. Fixed addresses are powered by [Portless](https://github.com/vercel-labs/portless) (Apache-2.0).
