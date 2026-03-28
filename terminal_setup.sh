#!/usr/bin/env bash
# =============================================================================
# Terminal Setup — Starship prompt, bash config, tmux, editor configs
# Pulls config files from GitHub repo so they stay in sync across machines.
#
# Usage:
#   bash terminal_setup.sh
# =============================================================================
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/romhom/linux_setup/main"
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
    local url="$REPO_RAW/$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    curl -fsSL "$url" -o "$dest" || die "Failed to fetch $url"
    log "$(basename "$dest") → $dest"
}

# ── Preflight ─────────────────────────────────────────────────────────────────
[[ "$EUID" -eq 0 ]] && die "Do not run as root."
command -v curl    >/dev/null || die "curl not found — run linux_setup.sh first"
command -v git     >/dev/null || die "git not found — run linux_setup.sh first"
command -v tmux    >/dev/null || die "tmux not found — run linux_setup.sh first"
command -v unzip   >/dev/null || die "unzip not found — run linux_setup.sh first"

# Ensure ~/.local/bin is on PATH (needed if running standalone before new shell)
export PATH="$HOME/.local/bin:$PATH"

# Verify repo is reachable before doing anything
curl -fsSL --head "$REPO_RAW/configs/starship.toml" > /dev/null 2>&1 \
    || die "Cannot reach $REPO_RAW — check internet and repo visibility"

# ── 1. Starship prompt ────────────────────────────────────────────────────────
section "Starship Prompt"
if ! command -v starship &>/dev/null; then
    # Install to ~/.local/bin to avoid sudo password prompt
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
    command -v starship >/dev/null || die "Starship install failed — binary not found"
    log "Starship installed: $(starship --version)"
else
    warn "Starship already installed ($(starship --version)) — skipping"
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

# Ensure fontconfig is available
if ! command -v fc-list &>/dev/null; then
    sudo apt install -y fontconfig
fi

if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
    info "Downloading JetBrainsMono Nerd Font (~50MB)..."
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    if curl -fsSL "$FONT_URL" -o /tmp/JetBrainsMono.zip; then
        unzip -o /tmp/JetBrainsMono.zip -d "$FONT_DIR/JetBrainsMono" '*.ttf' 2>/dev/null || true
        rm -f /tmp/JetBrainsMono.zip
        fc-cache -f "$FONT_DIR" > /dev/null
        log "JetBrainsMono Nerd Font installed"
        warn "Set terminal font to 'JetBrainsMono Nerd Font' for Starship symbols"
        warn "Chromebook: Terminal → Settings → Appearance → Custom font"
    else
        warn "Font download failed — Starship will work but symbols may not render correctly"
        warn "Install manually: https://www.nerdfonts.com/font-downloads"
    fi
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
warn "Run: source ~/.bashrc   (or restart your terminal)"
warn "Then: set terminal font to 'JetBrainsMono Nerd Font' in Terminal settings"
warn "Then: open tmux and press prefix + I to install plugins"
echo ""
