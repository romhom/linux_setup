#!/usr/bin/env bash
# =============================================================================
# install.sh — linux_setup
# Single entry point for Chromebook and any Debian/Ubuntu machine.
# Auto-detects platform, runs the full setup, applies terminal config.
#
# Usage (Chromebook or any Debian/Ubuntu):
#   curl -fsSL https://raw.githubusercontent.com/romhom/linux_setup/main/install.sh | bash
#
# Or if already cloned:
#   bash ~/linux_setup/install.sh
#
# Options:
#   --skip-checkpoints    ignore saved progress and run everything
#   --only <stage>        run a single stage: core | crostini | terminal
#   --check               run health check only (no install)
# =============================================================================
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/romhom/linux_setup/main"
DEST="$HOME/linux_setup"
CHECKPOINT_DIR="$HOME/.cache/linux_setup/checkpoints"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${GREEN}[✔]${RESET} $*"; }
info()    { echo -e "${CYAN}[→]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }
die()     { echo -e "${RED}[✘] $*${RESET}" >&2; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
SKIP_CHECKPOINTS=false
ONLY_STAGE=""
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-checkpoints) SKIP_CHECKPOINTS=true ;;
        --only) ONLY_STAGE="${2:-}"; shift ;;
        --check) CHECK_ONLY=true ;;
        *) warn "Unknown option: $1" ;;
    esac
    shift
done

# ── Platform detection ────────────────────────────────────────────────────────
_is_crostini() {
    [[ "$(hostname)" == "penguin" ]] || \
    grep -qi "cros\|chromeos" /proc/version 2>/dev/null || \
    [[ -f /etc/cros_chroot_config ]]
}

IS_CROSTINI=false
_is_crostini && IS_CROSTINI=true

# ── Checkpoint helpers ────────────────────────────────────────────────────────
mkdir -p "$CHECKPOINT_DIR"

checkpoint_done() {
    touch "$CHECKPOINT_DIR/$1"
}
checkpoint_exists() {
    [[ "$SKIP_CHECKPOINTS" == "true" ]] && return 1
    [[ -f "$CHECKPOINT_DIR/$1" ]]
}
checkpoint_clear() {
    rm -f "$CHECKPOINT_DIR/$1"
}

# ── Health check ──────────────────────────────────────────────────────────────
run_health_check() {
    section "Setup Health Check"

    local pass=0 fail=0 warn_count=0

    check_tool() {
        local name="$1" cmd="$2"
        if command -v "$cmd" &>/dev/null; then
            log "$name ($(command -v "$cmd"))"
            ((pass++))
        else
            echo -e "${RED}[✘]${RESET} $name — not found"
            ((fail++))
        fi
    }

    check_file() {
        local name="$1" path="$2"
        if [[ -f "$path" ]]; then
            log "$name ($path)"
            ((pass++))
        else
            echo -e "${YELLOW}[!]${RESET} $name — not found at $path"
            ((warn_count++))
        fi
    }

    echo -e "\n${BOLD}Core tools${RESET}"
    check_tool "git"        git
    check_tool "curl"       curl
    check_tool "docker"     docker
    check_tool "gh"         gh
    check_tool "az"         az
    check_tool "code"       code

    echo -e "\n${BOLD}Python${RESET}"
    check_tool "uv"         uv
    check_tool "python3.12" python3.12
    check_tool "mamba"      mamba
    check_tool "direnv"     direnv
    check_tool "ruff"       ruff
    check_tool "pytest"     pytest
    check_tool "ipython"    ipython

    echo -e "\n${BOLD}Terminal tools${RESET}"
    check_tool "starship"   starship
    check_tool "tmux"       tmux
    check_tool "zoxide"     zoxide
    check_tool "delta"      delta
    check_tool "lazygit"    lazygit
    check_tool "bat"        bat
    check_tool "fzf"        fzf
    check_tool "ripgrep"    rg
    check_tool "glow"       glow

    echo -e "\n${BOLD}Config files${RESET}"
    check_file "starship config"    "$HOME/.config/starship.toml"
    check_file "tmux config"        "$HOME/.tmux.conf"
    check_file ".bashrc_extras"     "$HOME/.bashrc_extras"
    check_file "SSH key"            "$HOME/.ssh/id_ed25519"

    echo -e "\n${BOLD}SSH & GitHub${RESET}"
    if ssh -T git@github.com -o StrictHostKeyChecking=accept-new 2>&1 | grep -q "successfully authenticated"; then
        log "SSH key verified with GitHub"
        ((pass++))
    else
        echo -e "${YELLOW}[!]${RESET} SSH key not verified with GitHub"
        ((warn_count++))
    fi

    echo -e "\n${BOLD}PATH${RESET}"
    if echo "$PATH" | grep -q "$HOME/.local/bin"; then
        log "~/.local/bin on PATH"
        ((pass++))
    else
        echo -e "${RED}[✘]${RESET} ~/.local/bin not on PATH"
        ((fail++))
    fi

    if _is_crostini; then
        echo -e "\n${BOLD}Crostini${RESET}"
        check_tool "gedit-sudo"  gedit-sudo
        check_file "sudoers display" "/etc/sudoers.d/crostini-display"
    fi

    echo ""
    echo -e "${BOLD}Results: ${GREEN}${pass} passed${RESET}  ${YELLOW}${warn_count} warnings${RESET}  ${RED}${fail} failed${RESET}"

    if [[ "$fail" -gt 0 ]]; then
        echo ""
        warn "Some tools missing. Run: bash ~/linux_setup/install.sh --skip-checkpoints"
    fi
    echo ""
}

# ── Health check only mode ────────────────────────────────────────────────────
if [[ "$CHECK_ONLY" == "true" ]]; then
    run_health_check
    exit 0
fi

# ── Fetch all files ───────────────────────────────────────────────────────────
fetch() {
    local path="$1"
    local dest="$DEST/$path"
    mkdir -p "$(dirname "$dest")"
    curl -fsSL "$REPO_RAW/$path" -o "$dest"
    log "$path"
}

section "Fetching linux_setup"
echo "  Source: $REPO_RAW"
echo "  Dest:   $DEST"
if $IS_CROSTINI; then
    echo "  Platform: Chromebook (Crostini)"
else
    echo "  Platform: Linux (Debian/Ubuntu)"
fi
echo ""

mkdir -p "$DEST/configs"

fetch "install.sh"
fetch "update.sh"
fetch "linux_setup.sh"
fetch "chromebook_crostini.sh"
fetch "terminal_setup.sh"
fetch "configs/starship.toml"
fetch "configs/starship_simple.toml"
fetch "configs/.bashrc_extras"
fetch "configs/tmux.conf"
fetch "configs/.nanorc"
fetch "configs/micro_settings.json"

chmod +x "$DEST"/*.sh

# ── Stage runner ──────────────────────────────────────────────────────────────
run_stage() {
    local stage="$1"
    local script="$2"
    local label="$3"

    # If --only was specified, skip non-matching stages
    if [[ -n "$ONLY_STAGE" && "$ONLY_STAGE" != "$stage" ]]; then
        return
    fi

    if checkpoint_exists "$stage"; then
        warn "$label — already completed (use --skip-checkpoints to re-run)"
        return
    fi

    section "$label"
    if bash "$script"; then
        checkpoint_done "$stage"
        log "$label complete"
    else
        die "$label failed — fix the error and re-run. Completed stages will be skipped."
    fi
}

# ── Run stages ────────────────────────────────────────────────────────────────
run_stage "core"     "$DEST/linux_setup.sh"          "Core Setup"

if $IS_CROSTINI; then
    run_stage "crostini" "$DEST/chromebook_crostini.sh"  "Crostini Extras"
fi

run_stage "terminal" "$DEST/terminal_setup.sh"       "Terminal Setup"

# ── Post-install summary ──────────────────────────────────────────────────────
section "Setup Complete"
echo -e "${GREEN}${BOLD}"
echo "  Everything is installed and configured."
echo ""
if $IS_CROSTINI; then
    echo "  Platform:  Chromebook (Crostini)"
else
    echo "  Platform:  Linux (Debian/Ubuntu)"
fi
echo ""
echo "  ✔ Core tools, Python (uv), Docker, Azure CLI"
echo "  ✔ Terminal: Starship, tmux, zoxide, fzf, delta"
echo "  ✔ Python tools: ruff, mypy, pytest, ipython, and more"
if $IS_CROSTINI; then
    echo "  ✔ Crostini: display fix, gedit-sudo wrapper"
fi
echo -e "${RESET}"

echo -e "${BOLD}Next steps:${RESET}"
echo ""
echo "  1.  source ~/.bashrc          — apply shell config now"
echo "  2.  gh auth login             — authenticate with GitHub"
echo "  3.  ssh -T git@github.com     — verify SSH key"

if $IS_CROSTINI; then
    echo "  4.  Set terminal font → JetBrains Mono (Terminal → Settings → Appearance)"
    echo "  5.  Open tmux, press Ctrl+a then I — install plugins"
else
    echo "  4.  Open tmux, press Ctrl+a then I — install plugins"
fi

echo ""
echo -e "${BOLD}Useful commands:${RESET}"
echo "  setup-check      — verify all tools are installed correctly"
echo "  setup-update     — pull latest scripts and configs from GitHub"
echo "  mkpy <name>      — scaffold a new Python project"
echo "  pyinfo           — show current Python environment"
echo ""

if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
    if ! ssh -T git@github.com -o StrictHostKeyChecking=accept-new 2>&1 | grep -q "successfully authenticated"; then
        echo -e "${YELLOW}[!]${RESET} SSH key not yet added to GitHub:"
        echo ""
        cat "$HOME/.ssh/id_ed25519.pub"
        echo ""
        echo "  Add at: https://github.com/settings/ssh/new"
        echo ""
    fi
fi
