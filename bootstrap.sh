#!/usr/bin/env bash
# =============================================================================
# Bootstrap — Chromebook Setup
# Downloads all scripts and configs, then runs the full setup.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/romhom/chromebook-setup/main/bootstrap.sh | bash
# =============================================================================
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/romhom/chromebook-setup/main"
DEST="$HOME/chromebook-setup"

BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'; RESET='\033[0m'

section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }
log()     { echo -e "${GREEN}[✔]${RESET} $*"; }

fetch() {
    local path="$1"
    local dest="$DEST/$path"
    mkdir -p "$(dirname "$dest")"
    curl -fsSL "$REPO_RAW/$path" -o "$dest"
    log "$path"
}

section "Bootstrapping chromebook-setup"
echo "  Fetching scripts from: $REPO_RAW"
echo "  Installing to:         $DEST"
echo ""

mkdir -p "$DEST/configs"

# ── Scripts ───────────────────────────────────────────────────────────────────
fetch "chromebook_setup.sh"
fetch "linux_setup.sh"
fetch "chromebook_crostini.sh"
fetch "terminal_setup.sh"

# ── Configs ───────────────────────────────────────────────────────────────────
fetch "configs/starship.toml"
fetch "configs/.bashrc_extras"
fetch "configs/tmux.conf"
fetch "configs/.nanorc"
fetch "configs/micro_settings.json"

chmod +x "$DEST"/*.sh

section "Running Setup"
bash "$DEST/chromebook_setup.sh"
