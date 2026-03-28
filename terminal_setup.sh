#!/usr/bin/env bash
# =============================================================================
# Terminal Setup — Starship prompt, bash config, tmux, editor configs
# Pulls config files from GitHub repo so they stay in sync across machines.
#
# Usage:
#   bash terminal_setup.sh
#
# Set REPO_RAW below to your own GitHub raw content URL.
# =============================================================================
set -euo pipefail

# ── Edit this to point at your repo ──────────────────────────────────────────
REPO_RAW="https://raw.githubusercontent.com/romhom/chromebook-setup/main"

BASHRC="$HOME/.bashrc"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${GREEN}[✔]${RESET} $*"; }
info()    { echo -e "${CYAN}[→]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }
die()     { echo -e "${RED}[✘] $*${RESET}" >&2; exit 1; }

fetch() {
    # fetch <remote_path> <local_dest>
    local url="$REPO_RAW/$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    curl -fsSL "$url" -o "$dest" || die "Failed to fetch $url"
    log "$(basename "$dest") installed → $dest"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
[[ "$EUID" -eq 0 ]] && die "Do not run as root."
command -v curl >/dev/null || die "curl not found — run linux_setup.sh first"

# ── 1. Starship prompt ────────────────────────────────────────────────────────
section "Starship Prompt"
if ! command -v starship &>/dev/null; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes
    log "Starship installed: $(starship --version)"
else
    warn "Starship already installed — skipping"
fi

# Pull starship config
fetch "configs/starship.toml" "$HOME/.config/starship.toml"

# Wire starship into .bashrc
if ! grep -q "starship init" "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# ── Starship prompt ───────────────────────────────────────────────────────────
eval "$(starship init bash)"
EOF
    log "Starship wired into .bashrc"
else
    warn "Starship already in .bashrc — skipping"
fi

# ── 2. Bash extras (.bashrc_extras) ──────────────────────────────────────────
section "Bash Config"
fetch "configs/.bashrc_extras" "$HOME/.bashrc_extras"

# Source it from .bashrc if not already
if ! grep -q ".bashrc_extras" "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# ── Extras (aliases, exports, functions) ─────────────────────────────────────
[[ -f "$HOME/.bashrc_extras" ]] && source "$HOME/.bashrc_extras"
EOF
    log ".bashrc_extras sourced from .bashrc"
else
    warn ".bashrc_extras already sourced — skipping"
fi

# ── 3. tmux config ────────────────────────────────────────────────────────────
section "tmux Config"
fetch "configs/tmux.conf" "$HOME/.tmux.conf"

# Install tmux plugin manager (tpm)
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR" ]]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    log "tmux plugin manager (tpm) installed"
    info "Open tmux and press prefix + I to install plugins"
else
    warn "tpm already installed — skipping"
fi

# ── 4. nano config ────────────────────────────────────────────────────────────
section "nano Config"
fetch "configs/.nanorc" "$HOME/.nanorc"

# ── 5. micro config ───────────────────────────────────────────────────────────
section "micro Config"
fetch "configs/micro_settings.json" "$HOME/.config/micro/settings.json"

# ── 6. Nerd Font ──────────────────────────────────────────────────────────────
section "Nerd Font"
# Starship uses powerline symbols — a Nerd Font is needed in the terminal
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
    info "Downloading JetBrainsMono Nerd Font..."
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    curl -fsSL "$FONT_URL" -o /tmp/JetBrainsMono.zip
    unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR/JetBrainsMono" '*.ttf' 2>/dev/null
    rm /tmp/JetBrainsMono.zip
    fc-cache -fv "$FONT_DIR" > /dev/null
    log "JetBrainsMono Nerd Font installed"
    warn "Set your terminal font to 'JetBrainsMono Nerd Font' for Starship symbols"
    warn "Chromebook: open Terminal → Settings → Appearance → Custom font"
else
    warn "JetBrainsMono Nerd Font already installed — skipping"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
section "Terminal Setup Complete"
echo -e "${GREEN}${BOLD}"
echo "  ✔ Starship prompt installed + configured"
echo "  ✔ Bash aliases, exports, functions (.bashrc_extras)"
echo "  ✔ tmux configured + tpm installed"
echo "  ✔ nano configured"
echo "  ✔ micro configured"
echo "  ✔ JetBrainsMono Nerd Font installed"
echo -e "${RESET}"
warn "Restart your terminal to apply all changes."
warn "Then set terminal font to 'JetBrainsMono Nerd Font' in Terminal settings."
echo ""
