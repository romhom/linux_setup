#!/usr/bin/env bash
# =============================================================================
# Chromebook Setup — Orchestrator
# Runs the portable Linux core, then applies Crostini-specific config.
#
# Usage:
#   bash chromebook_setup.sh
#
# On any other Debian/Ubuntu machine, run just:
#   bash linux_setup.sh
# =============================================================================
set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; RESET='\033[0m'

section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

section "Chromebook Setup — Starting"
echo "  Running core Linux setup, then Crostini extras..."
echo ""

bash "$SCRIPT_DIR/linux_setup.sh"
bash "$SCRIPT_DIR/chromebook_crostini.sh"

section "All Done"
echo "Restart your terminal (or run 'source ~/.bashrc') to apply all changes."
echo "If Docker was newly installed, log out and back in to your Linux session."
echo ""
echo "Next: bash terminal_setup.sh"
echo ""
