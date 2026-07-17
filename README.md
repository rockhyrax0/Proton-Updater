# proton-updater

**Keep CachyOS Proton and GE-Proton current for Steam, automatically. No GUI, no daemon, no Python.**

[![CI](https://github.com/rockhyrax0/Proton-Updater/actions/workflows/ci.yml/badge.svg)](https://github.com/rockhyrax0/Proton-Updater/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

`proton-updater` is a single Bash script that checks GitHub for new [proton-cachyos](https://github.com/CachyOS/proton-cachyos) and [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) releases, picks the right build for your CPU, downloads and verifies it, and wires it into Steam — and, because they share a runner directory, into Faugus Launcher, Lutris and Heroic at the same time. Pair it with the included systemd user timer and you stop thinking about Proton versions.

It only ever writes inside `$HOME`, so it works the same on Silverblue, Bazzite, SteamOS, MicroOS and NixOS as it does on Arch, Fedora or Ubuntu.

---

## Why not just use ProtonUp-Qt?

Use ProtonUp-Qt if you like it — it's a good tool and it's more discoverable than this. But it's a GUI, which means your Proton builds update when *you* remember to open it and click a button.

`proton-updater` is for people who want Proton to update the way their packages do: on a schedule, in the background, with a journal to read when something breaks. It also fetches the CachyOS `x86_64_v3` build, which some launchers won't fetch for you at all.

## Features

- **Dependency-light.** Bash, coreutils, `tar`, and `curl` *or* `wget`. `jq` is used when present; otherwise it falls back to a `grep`/`sed` parser for the GitHub API response.
- **Stable tool names, rolling targets.** Steam always sees `Proton-CachyOS-Latest-v3` and `Proton-GE-Latest`. Pin a game to one once and it keeps getting newer builds forever — no re-pinning after every update.
- **One-dropdown rollback.** `Proton-CachyOS-Previous-v3` and `Proton-GE-Previous` always point at the build before the current one. New build breaks a game? Switch the dropdown, keep playing.
- **CPU-aware.** Asks glibc's own loader which micro-arch tier it will use rather than hand-parsing `/proc/cpuinfo`, then picks the `x86_64_v3` CachyOS build when supported and the baseline when not. Anchored patterns mean `x86_64` can never accidentally grab the `x86_64_v3` asset.
- **Every Steam — and not only Steam.** Native, Flatpak (both known data-dir layouts) and Snap are all discovered and updated in one run. Because `~/.local/share/Steam/compatibilitytools.d` doubles as the shared runner directory for the umu ecosystem, Faugus Launcher, Lutris and Heroic pick the same builds up with no extra work. See [Does this work with Lutris, Faugus or Heroic?](#does-this-work-with-lutris-faugus-or-heroic)
- **Live progress notifications.** A single popup that updates in place with a real progress bar on KDE, GNOME, dunst and mako. Degrades cleanly to one static notification on older `notify-send`, and to silence with `NO_NOTIFY=1`.
- **Atomic installs.** Copy to `.<name>.tmp`, then rename into place. An interrupted run never leaves a half-written build for Steam to find.
- **Reflink-aware.** `cp --reflink=auto` makes installs instant and nearly free on btrfs and XFS.
- **Checksum verification.** SHA-512 or SHA-256, GNU (`hash  file`) and BSD (`SHA256 (file) = hash`) formats both handled, position-independently.
- **Never uses `/tmp`.** `/tmp` is tmpfs (RAM) on most systemd distros, and a multi-GB Proton extraction would OOM there. Work happens in your XDG cache dir, on the same filesystem as `$HOME`, which also keeps reflinks possible.
- **Concurrency-safe.** A `flock` guard means a timer firing mid-download can't collide with a manual run.
- **Self-cleaning.** Keeps the last two builds per provider by default; older ones are pruned automatically.

## How it works

The design point is that **Steam's view of the tool never changes, but what it points at does.**

Builds are stored in a `proton-updater/` directory *next to* `compatibilitytools.d`, not inside it. `compatibilitytools.d` only ever contains symlinks:

```
~/.local/share/Steam/
├── compatibilitytools.d/
│   ├── Proton-CachyOS-Latest-v3   -> ../proton-updater/cachyos-builds/proton-cachyos-10.0-20250715-slr-x86_64_v3
│   ├── Proton-CachyOS-Previous-v3 -> ../proton-updater/cachyos-builds/proton-cachyos-10.0-20250601-slr-x86_64_v3
│   ├── Proton-GE-Latest           -> ../proton-updater/ge-builds/GE-Proton10-4
│   └── Proton-GE-Previous         -> ../proton-updater/ge-builds/GE-Proton10-3
└── proton-updater/
    ├── cachyos-builds/
    │   ├── proton-cachyos-10.0-20250715-slr-x86_64_v3/   ← Latest
    │   └── proton-cachyos-10.0-20250601-slr-x86_64_v3/   ← Previous
    └── ge-builds/
        ├── GE-Proton10-4/
        └── GE-Proton10-3/
```

Two reasons it's built this way:

- **Launchers that enumerate `compatibilitytools.d`** (Faugus, Lutris, and anything else on umu) would otherwise list every raw build folder as a separate runner. They only see the four symlinks. Steam just follows them, so it's unaffected.
- **The symlink targets are relative**, so they resolve identically inside a Flatpak Steam sandbox and on the host.

A run does, in order:

1. Preflight for required tools; `flock` against a concurrent run; wait for the network (up to `NET_WAIT`).
2. Discover every Steam compat dir on the machine.
3. Pick the right asset pattern for this CPU, per provider.
4. Query the GitHub Releases API for the latest release.
5. Skip the download entirely if every target dir already has that build.
6. Download with a live progress notification, verify the checksum, extract.
7. Copy into the build store (reflink where possible), rename into place atomically.
8. Prune to `KEEP_BUILDS`, write the VDF registration, repoint the Latest/Previous symlinks.

## Requirements

| | |
|---|---|
| **Required** | `bash` (3.1+ — any Linux bash qualifies), coreutils, `tar`, `sed`, `find`, and either `curl` or `wget` |
| **Recommended** | `jq`, `flock` (util-linux), `xz` (CachyOS `.tar.xz`), `gzip` (GE `.tar.gz`), `sha512sum`/`sha256sum` |
| **Optional** | `notify-send` (libnotify) for desktop notifications |
| **Scheduling** | `systemd` with user session support |

Everything optional degrades with a logged note rather than failing. Missing `jq` falls back to a `grep`/`sed` parser; missing `sha*sum` skips verification; missing `notify-send` runs silently.

## Install

```bash
git clone https://github.com/rockhyrax0/Proton-Updater.git
cd Proton-Updater
bash install.sh
```

That installs the script to `~/.local/bin` and the systemd user units to `~/.config/systemd/user`. **It doesn't schedule anything.** Nothing touches your Steam directories until you run it.

Try a run first and see what it decides to do:

```bash
proton-updater
```

Happy with it? Turn on the twice-daily timer:

```bash
bash install.sh --enable
```

<details>
<summary>Manual install</summary>

```bash
install -Dm755 proton-updater ~/.local/bin/proton-updater
install -Dm644 systemd/proton-updater.service ~/.config/systemd/user/proton-updater.service
install -Dm644 systemd/proton-updater.timer   ~/.config/systemd/user/proton-updater.timer

systemctl --user daemon-reload
systemctl --user enable --now proton-updater.timer   # omit to leave the timer off
```

Make sure `~/.local/bin` is on your `PATH`.
</details>

### Uninstall

```bash
bash install.sh --uninstall
```

Removes the script and units. Installed Proton builds are left alone — delete `<steam-root>/proton-updater/` yourself if you want them gone.

## Usage

```bash
proton-updater          # run it now
proton-updater --help   # usage
```

Or through systemd, which is what the timer does, and which logs to the journal:

```bash
systemctl --user start proton-updater.service
```

`--help` is the only flag. Everything else is configured by environment.

## Configuration

Set them inline for a one-off run:

```bash
KEEP_BUILDS=4 proton-updater
```

...or persist them for the timer:

```bash
systemctl --user edit proton-updater.service
```

```ini
[Service]
Environment=KEEP_BUILDS=4
Environment=GITHUB_TOKEN=ghp_...
```

| Variable | Default | Description |
|---|---|---|
| `KEEP_BUILDS` | `2` | Builds retained per provider. The default of 2 is what backs the Latest/Previous pair — set it to 1 and you lose rollback. |
| `NET_WAIT` | `30` | Seconds to wait for the network before trying anyway. |
| `CACHYOS_PATTERN` | *(auto)* | Pin CachyOS asset selection to a regex, bypassing CPU detection. May be a newline-separated preference list; first match wins. |
| `GE_PATTERN` | *(auto)* | Same, for GE-Proton. |
| `GE_EXCLUDE` | *(auto)* | Regex of GE assets to drop before matching — this is how the aarch64 build is kept out of the way on x86_64. |
| `STEAM_COMPAT_DIRS` | *(auto)* | Explicit `:`-separated compat dirs, bypassing discovery. Useful for testing against a throwaway directory. |
| `PROTON_UPDATER_CACHE` | `$XDG_CACHE_HOME/proton-updater` | Work/cache directory. Must be on persistent storage with room for a full extraction — not tmpfs. |
| `GITHUB_TOKEN` | *(unset)* | Raises the GitHub API rate limit from 60/hr to 5000/hr. Needs no scopes. |
| `NO_NOTIFY` | *(unset)* | Set to suppress all desktop notifications. |
| `DL_ICON` | `folder-download` | Icon name for the download progress popup. |
| `NO_VERIFY` | *(unset)* | Set to skip checksum verification entirely. |
| `VERIFY_STRICT` | *(unset)* | Set to make a checksum mismatch fatal instead of a warning. |

## Scheduling

The timer is **not enabled by default** — `bash install.sh --enable` (or `systemctl --user enable --now proton-updater.timer`) turns it on. Once running, it fires at **09:00 and 18:00** daily:

```ini
[Timer]
OnCalendar=09:00
OnCalendar=18:00
Persistent=true
RandomizedDelaySec=300
```

Two details that matter:

- **`Persistent=true`** means a run missed while the machine was off or asleep fires shortly after you're back. This is why the timer is wall-clock (`OnCalendar=`) rather than monotonic — monotonic timers (`OnBootSec=`/`OnUnitActiveSec=`) freeze across suspend and silently drift.
- **`RandomizedDelaySec=300`** spreads the load so everyone running this doesn't hit GitHub at 09:00:00 exactly.

Change the schedule with an override rather than editing the shipped unit:

```bash
systemctl --user edit proton-updater.timer
```

```ini
[Timer]
OnCalendar=
OnCalendar=daily
```

The empty `OnCalendar=` is required — it clears the shipped values instead of adding to them.

```bash
systemctl --user list-timers proton-updater.timer   # when does it next fire?
```

## Verification

Assets are downloaded over HTTPS and checked against the release's published SHA-512 or SHA-256, in whichever of the two common formats upstream used.

When a mismatch happens, the default is to **warn and proceed**. That's a deliberate call: the transfer was HTTPS, the archive carries its own CRC, and a genuinely corrupt file fails at extraction a few seconds later anyway. Blocking a good update on a checksum quirk — an upstream re-upload, a stale sums file — costs more than it saves. Set `VERIFY_STRICT=1` if you'd rather have the hard guarantee, or `NO_VERIFY=1` to skip the check entirely.

Verification is also skipped, with a log line, when upstream publishes no checksum or when no `sha*sum` tool is installed.

One caveat worth stating plainly: both upstreams publish checksums to the same GitHub release as the asset. A match proves the bytes you got are the bytes GitHub served. It does not prove GitHub served the right bytes.

## FAQ

### Will updating force my shader caches to recompile?

Partly yes — but the naming scheme isn't why, and no alternative design avoids it.

A Proton update ships new DXVK and VKD3D-Proton. Those generate different SPIR-V from the same game shaders, so Mesa's on-disk cache misses and pipelines get rebuilt on first launch. That's true of *any* Proton update by any tool, including clicking the button in ProtonUp-Qt. Steam's Fossilize pre-caching isn't a factor either way — Valve only ships precompiled pipelines for official Proton, not for custom compatibility tools.

What the rolling-symlink design actually changes is **when**: the swap happens on a timer instead of when you chose it, so the stutter can arrive on a launch you weren't expecting it on.

That's what `Proton-CachyOS-Previous-v3` and `Proton-GE-Previous` are for. If a new build misbehaves, switch the game's compatibility tool to Previous and you're back on the old build immediately — no re-download.

If you'd rather never be surprised, disable the timer and run `proton-updater` by hand when it suits you. You keep the stable IDs and the rollback either way.

### Does it delete old versions?

Yes — it keeps the two most recent builds per provider (`KEEP_BUILDS=2`) and prunes the rest after a successful install. That's what makes Latest/Previous work. Raise `KEEP_BUILDS` if you want deeper history; the extra builds stay on disk, but only the newest two are ever symlinked.

Pruning only runs when a new build actually installs, so lowering `KEEP_BUILDS` won't take effect until the next real update.

### Do I need to restart Steam?

Yes, if Steam was running during the update. Steam reads `compatibilitytools.d` at startup, so a newly added tool won't appear in the dropdown until you restart the client.

For an update to an *existing* tool the symlink is repointed underneath Steam, so a restart is still the safe move — but you won't lose the pin either way, because the tool ID didn't change.

### Does this work with Lutris, Faugus or Heroic?

Yes — and it needs no configuration, because `~/.local/share/Steam/compatibilitytools.d` has become the de-facto shared runner directory for the umu ecosystem. That's one of the paths this script always populates, so the builds simply show up.

- **Faugus Launcher** documents that exact directory as its runners location, and its own README tells you to symlink native `proton-cachyos` / `proton-ge-custom` builds into it by hand. This script is that instruction, automated. Faugus's built-in Proton Manager only fetches GE-Proton and Proton-EM, so this is also the path of least resistance for getting the CachyOS `x86_64_v3` build in front of it.
- **Lutris** scans the same directory for Proton builds and hands whichever you select to umu.
- **Heroic** and anything else built on umu-launcher follows the same convention.

They'll appear under this script's names — `Proton-CachyOS-Latest-v3`, `Proton-GE-Latest` — and rollback via the matching `Previous` entry works the same everywhere.

**If you also use Faugus's Proton Manager**, note that it installs GE-Proton as `Proton-GE Latest` (with a space), while this script installs `Proton-GE-Latest` (all hyphens). They're different entries pointing at different builds, updated by different tools, and both will show in the list. Pick one and let it own the job, or you'll spend a while wondering which one a game is actually using.

### Why does it create `~/.local/share/Steam` even though I only use Flatpak Steam?

Deliberately — see the answer above. That path is where Faugus, Lutris and the rest of the umu ecosystem look for runners regardless of how Steam itself is installed, and Faugus's own manager won't fetch the CachyOS `x86_64_v3` build at all. Force-creating the directory means the build lands somewhere they can find it.

If you'd rather it only touch directories that already exist, delete the `mkdir -p` line in `discover_compat_dirs` — it's commented for exactly this.

### Will this touch my system, or need root?

No. The script goes in `~/.local/bin`, units in `~/.config/systemd/user`, builds under your Steam root. No root, no system packages, no daemon. That's why it works unmodified on immutable distros.

### I'm behind a VPN or CGNAT and it started failing

The GitHub API allows 60 unauthenticated requests per hour **per IP**. A run uses only a handful, so you won't hit that alone — but on a shared exit IP you're pooled with everyone else on it. If the journal shows HTTP 403 with a rate-limit message, that's what happened.

Fix it with a token — no scopes required:

```bash
systemctl --user edit proton-updater.service
```

```ini
[Service]
Environment=GITHUB_TOKEN=ghp_yourtokenhere
```

That takes you to 5000 requests/hour.

### Does it work on ARM64?

It'll fetch the right builds — CachyOS's arm64 asset and GE's aarch64 one. Actually *running* them needs FEX plus an x86 Steam (or umu), which is upstream's problem rather than this script's. Treat it as experimental.

### Why both CachyOS Proton and GE-Proton?

Different trade-offs, and plenty of people want both available. CachyOS Proton is built with aggressive optimizations and ships the `x86_64_v3` variant. GE-Proton carries a broader patch set for specific game and anti-cheat compatibility. Neither is a superset of the other.

## Troubleshooting

**See what it did:**

```bash
journalctl --user -u proton-updater.service -n 50 --no-pager
```

**Follow a run live:**

```bash
journalctl --user -u proton-updater.service -f
```

**Force a run now:**

```bash
systemctl --user start proton-updater.service
```

**Is the timer actually enabled?**

```bash
systemctl --user list-timers proton-updater.timer
systemctl --user status proton-updater.timer
```

**Timer never fires on a headless box** — user timers only run while your user manager is alive. Enable lingering:

```bash
loginctl enable-linger "$USER"
```

**"No Steam install found"** — discovery checks the native, Flatpak (both layouts), and Snap paths. If yours is somewhere unusual, point it there explicitly:

```bash
STEAM_COMPAT_DIRS=/path/to/Steam/compatibilitytools.d proton-updater
```

**Extraction failed** — install `xz` (CachyOS builds) or `gzip` (GE builds). Preflight warns about both if they're missing.

**Test a calendar expression before committing to it:**

```bash
systemd-analyze calendar "09:00"
```

## Contributing

Bug reports and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgements

- [CachyOS](https://github.com/CachyOS/proton-cachyos) for proton-cachyos
- [Thomas Crider (GloriousEggroll)](https://github.com/GloriousEggroll) for GE-Proton
- [ProtonUp-Qt](https://davidotek.github.io/protonup-qt/), which does this with a GUI and does it well
