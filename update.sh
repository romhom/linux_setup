#!/usr/bin/env bash
# =============================================================================
# Update — re-fetches all scripts and configs from GitHub and re-applies them.
#
# Usage:
#   bash ~/linux_setup/update.sh
#
# Or from anywhere if ~/linux_setup is on PATH:
#   update.sh
# =============================================================================
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/romhom/linux_setup/main"
DEST="$HOME/linux_setup"

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'

section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }
log()     { echo -e "${GREEN}[✔]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
die()     { echo -e "${RED}[✘] $*${RESET}" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
command -v curl >/dev/null || die "curl not found"
curl -fsSL --head "$REPO_RAW/bootstrap.sh" > /dev/null 2>&1 \
    || die "Cannot reach $REPO_RAW — check internet connection and repo visibility"

# ── Fetch a file, report if changed ──────────────────────────────────────────
fetch() {
    local path="$1"
    local dest="$DEST/$path"
    local tmp
    tmp=$(mktemp)

    mkdir -p "$(dirname "$dest")"
    curl -fsSL "$REPO_RAW/$path" -o "$tmp" || { warn "Failed to fetch $path — skipping"; rm -f "$tmp"; return; }

    if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
        warn "$path — unchanged"
    else
        mv "$tmp" "$dest"
        log "$path — updated"
    fi
    rm -f "$tmp"
}

# ── Apply configs to their live locations ─────────────────────────────────────
apply_configs() {
    section "Applying Configs"

    # starship — update both configs, preserve active symlink choice
    mkdir -p "$HOME/.config/starship"
    if ! cmp -s "$DEST/configs/starship.toml" "$HOME/.config/starship/nerd.toml" 2>/dev/null; then
        cp "$DEST/configs/starship.toml" "$HOME/.config/starship/nerd.toml"
        log "starship nerd.toml updated"
    else
        warn "starship nerd.toml — unchanged"
    fi
    if ! cmp -s "$DEST/configs/starship_simple.toml" "$HOME/.config/starship/simple.toml" 2>/dev/null; then
        cp "$DEST/configs/starship_simple.toml" "$HOME/.config/starship/simple.toml"
        log "starship simple.toml updated"
    else
        warn "starship simple.toml — unchanged"
    fi

    # bashrc_extras
    if ! cmp -s "$DEST/configs/.bashrc_extras" "$HOME/.bashrc_extras" 2>/dev/null; then
        cp "$DEST/configs/.bashrc_extras" "$HOME/.bashrc_extras"
        log ".bashrc_extras applied"
    else
        warn ".bashrc_extras — unchanged"
    fi

    # tmux
    if ! cmp -s "$DEST/configs/tmux.conf" "$HOME/.tmux.conf" 2>/dev/null; then
        cp "$DEST/configs/tmux.conf" "$HOME/.tmux.conf"
        log "tmux.conf applied"
        # reload tmux if running
        if command -v tmux &>/dev/null && tmux info &>/dev/null 2>&1; then
            tmux source-file "$HOME/.tmux.conf" && log "tmux config reloaded"
        fi
    else
        warn "tmux.conf — unchanged"
    fi

    # nano
    if ! cmp -s "$DEST/configs/.nanorc" "$HOME/.nanorc" 2>/dev/null; then
        cp "$DEST/configs/.nanorc" "$HOME/.nanorc"
        log ".nanorc applied"
    else
        warn ".nanorc — unchanged"
    fi

    # micro
    mkdir -p "$HOME/.config/micro"
    if ! cmp -s "$DEST/configs/micro_settings.json" "$HOME/.config/micro/settings.json" 2>/dev/null; then
        cp "$DEST/configs/micro_settings.json" "$HOME/.config/micro/settings.json"
        log "micro settings applied"
    else
        warn "micro settings — unchanged"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
section "Updating linux_setup from GitHub"
echo "  Repo: $REPO_RAW"
echo "  Local: $DEST"

section "Fetching Scripts"
fetch "install.sh"
fetch "update.sh"
fetch "linux_setup.sh"
fetch "chromebook_crostini.sh"
fetch "terminal_setup.sh"
chmod +x "$DEST"/*.sh

section "Fetching Configs"
fetch "configs/starship.toml"
fetch "configs/starship_simple.toml"
fetch "configs/.bashrc_extras"
fetch "configs/tmux.conf"
fetch "configs/.nanorc"
fetch "configs/micro_settings.json"

apply_configs

# ── Done ──────────────────────────────────────────────────────────────────────
section "Update Complete"
echo -e "${GREEN}${BOLD}"
echo "  Scripts updated in: $DEST"
echo "  Configs applied to home directory"
echo -e "${RESET}"
warn "Run 'source ~/.bashrc' to pick up any alias/function changes."
echo ""
