#!/usr/bin/env bash
#
# Installer for proton-updater.
#
# Installs the script to ~/.local/bin and the systemd user units to
# ~/.config/systemd/user. Does NOT start anything unless you ask it to.
# Everything lives under $HOME; no root required.
#
# Usage:
#   bash install.sh              Install only; the timer stays off (default)
#   bash install.sh --enable     Install, then start the twice-daily timer
#   bash install.sh --no-enable  Explicit form of the default
#   bash install.sh --uninstall  Remove the script and units
#
# Honors PREFIX (default: ~/.local).

set -euo pipefail

SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

SCRIPT_NAME="proton-updater"
UNITS=(proton-updater.service proton-updater.timer)

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }

have_systemd_user() {
    command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
}

do_install() {
    local enable_timer="$1"

    [[ -f "$SRC_DIR/$SCRIPT_NAME" ]] || die "$SCRIPT_NAME not found in $SRC_DIR"

    printf 'Installing proton-updater...\n'

    install -Dm755 "$SRC_DIR/$SCRIPT_NAME" "$BIN_DIR/$SCRIPT_NAME"
    info "$BIN_DIR/$SCRIPT_NAME"

    local unit
    for unit in "${UNITS[@]}"; do
        [[ -f "$SRC_DIR/systemd/$unit" ]] || die "systemd/$unit not found in $SRC_DIR"
        install -Dm644 "$SRC_DIR/systemd/$unit" "$UNIT_DIR/$unit"
        info "$UNIT_DIR/$unit"
    done

    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) printf '\nnote: %s is not on your PATH.\n' "$BIN_DIR"
           printf '      Add it to your shell profile to run proton-updater by name.\n' ;;
    esac

    if ! have_systemd_user; then
        printf '\nnote: no systemd user session detected. Units were installed but\n'
        printf '      not enabled. Run the script manually or enable the timer later.\n'
        return 0
    fi

    systemctl --user daemon-reload

    if [[ "$enable_timer" == "yes" ]]; then
        systemctl --user enable --now proton-updater.timer
        printf '\nTimer enabled. Next runs:\n\n'
        systemctl --user list-timers proton-updater.timer --no-pager
    else
        printf '\nInstalled. Nothing is scheduled yet — try a run first:\n'
        printf '  proton-updater\n'
        printf '\nThen enable the twice-daily timer when you are happy with it:\n'
        printf '  bash install.sh --enable\n'
    fi

    printf '\nRun under systemd with: systemctl --user start proton-updater.service\n'
    printf 'Read the log with:      journalctl --user -u proton-updater.service -f\n'
}

do_uninstall() {
    printf 'Uninstalling proton-updater...\n'

    if have_systemd_user; then
        systemctl --user disable --now proton-updater.timer 2>/dev/null || true
    fi

    local unit
    for unit in "${UNITS[@]}"; do
        if [[ -f "$UNIT_DIR/$unit" ]]; then
            rm -f "$UNIT_DIR/$unit"
            info "removed $UNIT_DIR/$unit"
        fi
    done

    if [[ -f "$BIN_DIR/$SCRIPT_NAME" ]]; then
        rm -f "$BIN_DIR/$SCRIPT_NAME"
        info "removed $BIN_DIR/$SCRIPT_NAME"
    fi

    if have_systemd_user; then
        systemctl --user daemon-reload
    fi

    printf '\nDone. Proton builds already installed into compatibilitytools.d were\n'
    printf 'left alone — remove them yourself if you want them gone.\n'
}

usage() {
    # Line 3 through the first blank line — range-based rather than a hardcoded
    # end, so editing the header can't leak code into --help.
    sed -n '3,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

main() {
    case "${1-}" in
        ''|--no-enable)  do_install no ;;
        --enable)        do_install yes ;;
        --uninstall)     do_uninstall ;;
        -h|--help)       usage ;;
        *)               die "unknown option: $1 (try --help)" ;;
    esac
}

main "$@"
