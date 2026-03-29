#!/usr/bin/env bash
# =============================================================================
# Chromebook Crostini — Extras
# Run after linux_setup.sh. Applies Crostini-specific fixes only.
# =============================================================================
set -euo pipefail

BASHRC="$HOME/.bashrc"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${GREEN}[✔]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

# ── 1. Display Protocol Fix ───────────────────────────────────────────────────
section "Crostini Display Fix"

# Export DISPLAY and XAUTHORITY so GUI apps always know where to render
if ! grep -q "DISPLAY=:0" "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# ── Crostini display fix ──────────────────────────────────────────────────────
export DISPLAY=:0
export XAUTHORITY=$HOME/.Xauthority
EOF
    log "Display vars added to .bashrc"
else
    warn "Display vars already in .bashrc — skipping"
fi

# Allow sudo to pass display vars through so 'sudo gedit' works
SUDOERS_FILE="/etc/sudoers.d/crostini-display"
if [[ ! -f "$SUDOERS_FILE" ]]; then
    echo 'Defaults env_keep += "DISPLAY XAUTHORITY"' | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 440 "$SUDOERS_FILE"
    log "sudoers display passthrough configured"
else
    warn "sudoers display config already exists — skipping"
fi

# ── 2. gedit-sudo wrapper ────────────────────────────────────────────────────
section "gedit-sudo Wrapper"

mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/gedit-sudo" <<'EOF'
#!/usr/bin/env bash
# Open a file in gedit as root, with display passthrough for Crostini
sudo -E env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" gedit "$@"
EOF
chmod +x "$HOME/.local/bin/gedit-sudo"
log "gedit-sudo wrapper installed — use instead of 'sudo gedit'"

# ── Done ──────────────────────────────────────────────────────────────────────
section "Crostini Config Complete"
echo -e "${GREEN}${BOLD}"
echo "  ✔ Display protocol fix applied"
echo "  ✔ sudoers passthrough configured"
echo "  Note: ChromeOS aliases (crdl, crfiles, crgdrive) are in .bashrc_extras"
echo "  ✔ gedit-sudo wrapper installed"
echo -e "${RESET}"
