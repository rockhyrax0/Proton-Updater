# proton-updater

**Keep CachyOS Proton and GE-Proton current for Steam, automatically. No GUI.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](https://www.gnu.org/software/bash/)

`proton-updater` is a single Bash script that checks GitHub for new [proton-cachyos](https://github.com/CachyOS/proton-cachyos) and [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) releases, picks the right build for your CPU, downloads and verifies it, and wires it into Steam — and, because they share a runner directory, into Faugus Launcher, Lutris and Heroic at the same time. Pair it with the included systemd timer and you stop thinking about Proton versions.

It only ever writes inside `$HOME`, so it works the same on Silverblue, Bazzite, SteamOS, MicroOS and NixOS as it does on Arch, Fedora or Ubuntu.

## Why not ProtonUp-Qt?

Use it if you like it — it's a good tool and more discoverable than this. But it's a GUI, so your builds update when *you* remember to open it and click. `proton-updater` updates Proton the way your packages update: on a schedule, in the background, with a journal to read when something breaks. It also fetches the CachyOS `x86_64_v3` build, which some launchers won't fetch for you at all.

## Features

- **Stable IDs, rolling targets.** Steam always sees `Proton-CachyOS-Latest-v3` and `Proton-GE-Latest`. Pin a game once and it keeps getting newer builds — no re-pinning after every update.
- **One-dropdown rollback.** `Proton-CachyOS-Previous-v3` and `Proton-GE-Previous` always point at the build before the current one. New build breaks a game? Switch the dropdown, keep playing.
- **CPU-aware.** Asks glibc's loader which micro-arch tier it will use instead of hand-parsing `/proc/cpuinfo`, then takes the `x86_64_v3` CachyOS build when supported and the baseline when not. Anchored patterns mean `x86_64` can never grab the `x86_64_v3` asset.
- **Not only Steam.** Native, Flatpak (both layouts) and Snap are all discovered in one run. Because `~/.local/share/Steam/compatibilitytools.d` doubles as the shared runner directory for the umu ecosystem, Faugus, Lutris and Heroic pick up the same builds with no extra work.
- **Live progress notifications.** A single popup that updates in place with a real progress bar on KDE and GNOME. Degrades to one static notification on older `notify-send`, and to silence with `NO_NOTIFY=1`.
- **Safe installs.** Copies to a `.tmp` name, then renames into place, so an interrupted run never leaves Steam a half-written build. A `flock` guard stops a timer firing mid-download from colliding with a manual run, reflink copies are near-instant on btrfs/XFS, downloads are checked against SHA-512/256, and it keeps the last two builds per provider and prunes the rest. Work happens in your XDG cache, never `/tmp` — that's tmpfs on most systemd distros, where a multi-GB extraction would OOM.
- **Dependency-light.** Bash, coreutils, `tar`, and `curl` *or* `wget`. `jq` is used when present; otherwise a `grep`/`sed` parser handles the GitHub API response.

## How it works

The design point is that **Steam's view of the tool never changes, but what it points at does.**

Builds live in a `proton-updater/` directory *next to* `compatibilitytools.d`, not inside it. `compatibilitytools.d` only ever contains symlinks:

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

- **Launchers that enumerate `compatibilitytools.d`** (Faugus, Lutris, anything else on umu) would otherwise list every raw build folder as a separate runner. They only see the four symlinks. Steam just follows them, so it's unaffected.
- **The symlink targets are relative**, so they resolve identically inside a Flatpak Steam sandbox and on the host.

## Requirements

| | |
|---|---|
| **Required** | `bash` (3.1+), coreutils, `tar`, `sed`, `find`, and either `curl` or `wget` |
| **Recommended** | `jq`, `flock` (util-linux), `xz` (CachyOS `.tar.xz`), `gzip` (GE `.tar.gz`), `sha512sum`/`sha256sum` |
| **Optional** | `notify-send` (libnotify) for desktop notifications |
| **Scheduling** | `systemd` with user session support |

Everything optional degrades with a logged note rather than failing.

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

`--help` is the only flag. Everything else is configured by environment.

## Configuration

Set them inline for a one-off run:

```bash
KEEP_BUILDS=4 proton-updater
```

...or persist them for the timer with `systemctl --user edit proton-updater.service`:

```ini
[Service]
Environment=KEEP_BUILDS=4
Environment=GITHUB_TOKEN=ghp_...
```

| Variable | Default | Description |
|---|---|---|
| `KEEP_BUILDS` | `2` | Builds retained per provider. 2 is what backs the Latest/Previous pair — set it to 1 and you lose rollback. |
| `NET_WAIT` | `30` | Seconds to wait for the network before trying anyway. |
| `CACHYOS_PATTERN` | *(auto)* | Pin CachyOS asset selection to a regex, bypassing CPU detection. May be a newline-separated preference list; first match wins. |
| `GE_PATTERN` | *(auto)* | Same, for GE-Proton. |
| `GE_EXCLUDE` | *(auto)* | Regex of GE assets to drop before matching — how the aarch64 build is kept out of the way on x86_64. |
| `STEAM_COMPAT_DIRS` | *(auto)* | Explicit `:`-separated compat dirs, bypassing discovery. Useful for testing against a throwaway directory. |
| `PROTON_UPDATER_CACHE` | `$XDG_CACHE_HOME/proton-updater` | Work/cache directory. Must be on persistent storage with room for a full extraction — not tmpfs. |
| `GITHUB_TOKEN` | *(unset)* | Raises the GitHub API rate limit from 60/hr to 5000/hr. Needs no scopes. |
| `NO_NOTIFY` | *(unset)* | Suppress all desktop notifications. |
| `DL_ICON` | `folder-download` | Icon name for the download progress popup. |
| `NO_VERIFY` | *(unset)* | Skip checksum verification entirely. |
| `VERIFY_STRICT` | *(unset)* | Make a checksum mismatch fatal instead of a warning. |

## Scheduling

The timer is **off by default** — `bash install.sh --enable` (or `systemctl --user enable --now proton-updater.timer`) turns it on. Once running, it fires at **09:00 and 18:00** daily:

```ini
[Timer]
OnCalendar=09:00
OnCalendar=18:00
Persistent=true
RandomizedDelaySec=300
```

- **`Persistent=true`** runs a job missed while the machine was off or asleep shortly after you're back. That's why the timer is wall-clock (`OnCalendar=`) rather than monotonic — monotonic timers (`OnBootSec=`/`OnUnitActiveSec=`) freeze across suspend and drift.
- **`RandomizedDelaySec=300`** keeps everyone running this from hitting GitHub at 09:00:00 exactly.

Change the schedule with an override rather than editing the shipped unit (`systemctl --user edit proton-updater.timer`):

```ini
[Timer]
OnCalendar=
OnCalendar=daily
```

The empty `OnCalendar=` is required — it clears the shipped values instead of adding to them.

## Verification

Assets are downloaded over HTTPS and checked against the release's published SHA-512 or SHA-256, in whichever of the two common formats upstream used.

On a mismatch, the default is to **warn and proceed**. That's deliberate: the transfer was HTTPS, the archive carries its own CRC, and a genuinely corrupt file fails at extraction a few seconds later anyway. Blocking a good update on a checksum quirk — a stale sums file, an upstream re-upload — costs more than it saves. Set `VERIFY_STRICT=1` for the hard guarantee, or `NO_VERIFY=1` to skip the check.

One caveat worth stating plainly: both upstreams publish checksums to the same GitHub release as the asset. A match proves the bytes you got are the bytes GitHub served. It does not prove GitHub served the right bytes.

## FAQ

### Will updating force my shader caches to recompile?

Partly — but the naming scheme isn't why, and no design avoids it. A Proton update ships new DXVK and VKD3D-Proton, which generate different SPIR-V from the same game shaders, so Mesa's on-disk cache misses and pipelines rebuild on first launch. That's true of *any* Proton update by any tool, including clicking the button in ProtonUp-Qt. What the rolling-symlink design changes is *when*: the swap happens on a timer, so the stutter can land on a launch you weren't expecting it on. That's what `Previous` is for — switch back and you're on the old build immediately, no re-download. Prefer never being surprised? Disable the timer and run `proton-updater` by hand.

### Does it delete old versions?

It keeps the two most recent builds per provider (`KEEP_BUILDS=2`) and prunes the rest after a successful install — that's what makes Latest/Previous work. Raise `KEEP_BUILDS` for deeper history. Pruning only runs when a new build installs, so lowering it won't take effect until the next update.

### Do I need to restart Steam?

If it was running during the update, yes — Steam reads `compatibilitytools.d` at startup. You won't lose a pin either way, since the tool ID didn't change.

### Does this work with Lutris, Faugus or Heroic?

Yes, with no configuration, because `~/.local/share/Steam/compatibilitytools.d` is the default shared runner directory for the umu ecosystem — one of the paths this script always populates. Builds show up under this script's names (`Proton-CachyOS-Latest-v3`, `Proton-GE-Latest`), and `Previous` rollback works the same everywhere.

This is also why it force-creates `~/.local/share/Steam` even if you only run Flatpak Steam: that path is where these launchers look regardless of how Steam is installed, and Faugus's own manager won't fetch the CachyOS `x86_64_v3` build at all. To only touch directories that already exist, delete the commented `mkdir -p` in `discover_compat_dirs`.

If you also use Faugus's Proton Manager, note that it installs GE-Proton as `Proton-GE Latest` (with a space) while this installs `Proton-GE-Latest` (all hyphens). Different entries, different tools.

### Does it work on ARM64?

It'll fetch the right builds — CachyOS's arm64 asset and GE's aarch64 one — but actually running them needs FEX plus an x86 Steam (or umu), which is upstream's problem rather than this script's. Treat it as experimental.

### Why both CachyOS Proton and GE-Proton?

Different trade-offs, and plenty of people want both. CachyOS Proton is built with aggressive optimizations and ships the `x86_64_v3` variant. GE-Proton carries a broader patch set for specific game and anti-cheat compatibility. Neither is a superset of the other.

## Troubleshooting

```bash
journalctl --user -u proton-updater.service -n 50 --no-pager   # what happened
journalctl --user -u proton-updater.service -f                 # follow a run live
systemctl --user start proton-updater.service                  # force a run now
systemctl --user list-timers proton-updater.timer              # is the timer on?
```

- **"No Steam install found"** — discovery covers native, Flatpak (both layouts) and Snap. If yours is elsewhere, point it there: `STEAM_COMPAT_DIRS=/path/to/Steam/compatibilitytools.d proton-updater`.
- **Extraction failed** — install `xz` (CachyOS builds) or `gzip` (GE builds). Preflight warns if either is missing.
- **Timer never fires on a headless box** — user timers only run while your user manager is alive: `loginctl enable-linger "$USER"`.

## Contributing

Bug reports and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgements

- [CachyOS](https://github.com/CachyOS/proton-cachyos) for proton-cachyos
- [Thomas Crider (GloriousEggroll)](https://github.com/GloriousEggroll) for GE-Proton
- [ProtonUp-Qt](https://davidotek.github.io/protonup-qt/), which does this with a GUI and does it well
