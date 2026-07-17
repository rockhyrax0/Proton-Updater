# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-07-17

Initial public release.

### Added

- Automatic updates for CachyOS Proton and GE-Proton from the GitHub Releases API.
- Stable compatibility tool IDs (`Proton-CachyOS-Latest-v3`, `Proton-GE-Latest`)
  backed by rolling symlinks, so per-game pins survive updates.
- `Proton-CachyOS-Previous-v3` / `Proton-GE-Previous` symlinks for one-dropdown
  rollback to the prior build.
- Builds stored in a `proton-updater/` directory beside `compatibilitytools.d`
  rather than inside it, so launchers that enumerate the compat dir (Faugus, UMU)
  see only the symlinks. Symlink targets are relative, so they resolve correctly
  inside a Flatpak Steam sandbox.
- CPU micro-arch detection via glibc's loader, with a `/proc/cpuinfo` flag-parsing
  fallback for glibc < 2.33. Selects the CachyOS `x86_64_v3` build when supported,
  baseline otherwise.
- Anchored asset patterns so `x86_64` cannot match the `x86_64_v3` asset, and
  arch exclusion so GE's aarch64 tarball cannot be selected on x86_64.
- Arch tags derived from the asset actually downloaded, so a baseline build can
  never be labelled `-v3`.
- Steam discovery across native, Flatpak (both `.local/share/Steam` and
  `data/Steam` layouts), and Snap installs; all targets updated in one run.
- Live in-place download progress notifications with a progress bar on
  notification daemons that support the `int:value` hint, degrading to a single
  static popup on older `notify-send`.
- Atomic installs via `.tmp` copy plus rename.
- Reflink-aware copying (`cp --reflink=auto`) for btrfs and XFS.
- SHA-512/SHA-256 verification with position-independent parsing of both GNU and
  BSD checksum formats, and CRLF normalization. Warns by default;
  `VERIFY_STRICT=1` makes mismatches fatal, `NO_VERIFY=1` skips entirely.
- Automatic pruning to `KEEP_BUILDS` (default 2) per provider.
- `flock` guard against overlapping runs.
- `jq` JSON parsing with a `grep`/`sed` fallback.
- `curl`/`wget` abstraction with retries and timeouts on both.
- `GITHUB_TOKEN` support to raise the API rate limit.
- Work directory on persistent storage under the XDG cache dir rather than
  `/tmp`, which is tmpfs on most systemd distros and would OOM on a multi-GB
  extraction.
- Network wait with configurable timeout (`NET_WAIT`).
- systemd user units: twice-daily wall-clock timer with `Persistent=true` and
  `RandomizedDelaySec=300`.
- One-time migration of the legacy in-`compatibilitytools.d` build store to the
  sibling `proton-updater/` store, via rename (no re-download).

[Unreleased]: https://github.com/rockhyrax0/Proton-Updater/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/rockhyrax0/Proton-Updater/releases/tag/v1.0.0
