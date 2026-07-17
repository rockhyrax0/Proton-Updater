# Contributing

Thanks for your interest. This is a small project and intends to stay that way.

## Scope

`proton-updater` keeps Proton builds current, headlessly, writing only inside `$HOME`. Changes that keep it small, dependency-light, and boring are welcome. Changes that add a GUI, a daemon, a config file format, or a hard runtime dependency probably aren't — open an issue before you spend time on a PR.

## Before you open a PR

```bash
bash -n proton-updater
shellcheck --severity=style proton-updater install.sh
systemd-analyze verify systemd/proton-updater.service systemd/proton-updater.timer
```

All three should come back clean before you open a PR. There's a workflow in `.github/workflows/ci.yml` that runs the first two, but run them locally regardless — it's the local result that matters.

## Style

- **`set -u` only — deliberately not `set -e`.** One provider failing must not abort the run: `main()` tracks per-provider success and reports `OK:`/`Failed:` at the end, so a GitHub hiccup on CachyOS still lets GE update. If you add a failure path, return non-zero and let the caller decide; don't reach for `set -e`.
- **Portable over clever.** The script targets busybox-ish and BSD-ish userlands where it reasonably can — bracket expressions instead of GNU `sed`'s `I` flag, `stat -c` with a `stat -f` and `wc -c` fallback, GNU *and* BSD checksum formats. Keep that up.
- **Every optional tool needs a fallback and a log line.** `jq`, `flock`, `notify-send`, `sha*sum` and the progress-bar path all degrade rather than fail. New dependencies must too.
- **Quote your expansions.** ShellCheck at `--severity=style` is the bar.
- **Comments explain *why*, not *what*.** The existing ones carry real hard-won reasons — why not `/tmp`, why the loader is asked instead of `/proc/cpuinfo`, why builds live outside `compatibilitytools.d`. Match that.

### Existing ShellCheck suppressions

The two `ls -dt` calls in `prune_builds` and `refresh_symlinks` carry `# shellcheck disable=SC2012`. That's intentional: they sort by mtime, which `find` can't do without GNU-only `-printf`, and the paths are upstream release folder names — no spaces, no newlines. Don't "fix" them into `find`. If you add a new suppression, comment the justification next to it.

## Testing changes

The script writes into your real Steam directories. Point it somewhere disposable instead:

```bash
STEAM_COMPAT_DIRS=/tmp/fake-steam/compatibilitytools.d \
PROTON_UPDATER_CACHE=/var/tmp/pu-test \
proton-updater
```

Keep `PROTON_UPDATER_CACHE` off tmpfs — extraction needs multiple GB.

Worth exercising before you call a change done:

- **A clean-state run** — no prior install, empty build store. Asset selection and registration bugs surface here.
- **A no-op run** — already current. Should be quiet, fast, and download nothing.
- **A second update** — this is the only way to see Latest/Previous rotation and `prune_builds` actually run.
- **A concurrent run** — start two at once; the `flock` guard should make the second bow out.
- **`VERIFY_STRICT=1`** — the strict path is easy to break unnoticed, because the default warns and carries on.
- **`NO_VERIFY=1`, `NO_NOTIFY=1`** — the skip paths.
- **Both Steam flavors**, if you have them. Native and Flatpak diverge, and the symlinks must stay relative or they'll break inside the Flatpak sandbox.
- **Under the timer, not just by hand.** `systemctl --user start proton-updater.service` runs with no terminal and no `DISPLAY` guarantee. Things that work interactively can fail there.

Two traps worth knowing about, both already paid for once:

- **Check the journal, not just your terminal.** Output routed to stderr from inside a command substitution silently vanishes, and the two views disagree. Functions like `set_cachyos_pattern` log to stdout and set a global precisely so their output survives — call them directly, never via `$(...)`.
- **GitHub's asset ordering is not stable.** Anything that picks an asset must anchor its pattern. A bare `x86_64` match will happily grab the `x86_64_v3` tarball, and a bare `.tar.gz` will grab the aarch64 one.

## Commits

Present tense, imperative: "Fix checksum association for x86_64_v3 assets", not "Fixed…" or "Fixes…". Keep unrelated changes in separate commits.
