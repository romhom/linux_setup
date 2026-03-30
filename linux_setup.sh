#!/usr/bin/env bash
# =============================================================================
# Linux Core Setup — Debian/Ubuntu Python Dev Environment
# Portable: works on any Debian/Ubuntu based machine
# Called directly or via install.sh
# =============================================================================
set -euo pipefail

# Cleanup temp files on exit or interrupt
_TMPFILES=()
_cleanup() { rm -f "${_TMPFILES[@]}"; }
trap _cleanup EXIT INT TERM

BASHRC="$HOME/.bashrc"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()     { echo -e "${GREEN}[✔]${RESET} $*"; }
info()    { echo -e "${CYAN}[→]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
section() { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }
die()     { echo -e "${RED}[✘] $*${RESET}" >&2; exit 1; }

# ── Preflight ─────────────────────────────────────────────────────────────────
[[ "$EUID" -eq 0 ]] && die "Do not run as root. Script will use sudo where needed."
command -v apt >/dev/null || die "apt not found — is this a Debian/Ubuntu system?"

# Detect distro for Docker repo (debian vs ubuntu)
DISTRO_ID=$(. /etc/os-release && echo "$ID")
DISTRO_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

# Validate — these are embedded in URLs; reject anything non-alphanumeric
[[ "$DISTRO_ID"       =~ ^[a-zA-Z0-9_-]+$ ]] || die "Unexpected DISTRO_ID value: $DISTRO_ID"
[[ "$DISTRO_CODENAME" =~ ^[a-zA-Z0-9_.-]+$ ]] || die "Unexpected DISTRO_CODENAME value: $DISTRO_CODENAME"

# ── Guarantee PATH written first ──────────────────────────────────────────────
# Must be first in .bashrc so every subsequent eval (starship, zoxide etc) 
# can find binaries in ~/.local/bin on a fresh shell
if ! grep -q 'LINUX_SETUP_PATH' "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# LINUX_SETUP_PATH
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
EOF
    log "PATH added to .bashrc"
fi

# ── 1. Sources Preflight ──────────────────────────────────────────────────────
section "Sources Preflight"

# Remove known broken entries before attempting apt update
SOURCES="/etc/apt/sources.list"

# Buster is EOL and off main mirrors
if grep -q "buster" "$SOURCES" 2>/dev/null; then
    sudo sed -i '/buster/d' "$SOURCES"
    warn "Removed stale buster entries from sources.list"
fi

# Remove Steam repo if unsigned (common Crostini leftover)
STEAM_LIST="/etc/apt/sources.list.d/steam.list"
if [[ -f "$STEAM_LIST" ]]; then
    sudo rm -f "$STEAM_LIST"
    warn "Removed unsigned Steam repo"
fi

# Remove duplicate Docker entries from main sources.list
if grep -q "download.docker.com" "$SOURCES" 2>/dev/null; then
    sudo sed -i '/download.docker.com/d' "$SOURCES"
    warn "Removed duplicate Docker entry from sources.list"
fi

log "Sources list clean"

# ── 2. System Update ──────────────────────────────────────────────────────────
section "System Update"
sudo apt update -o Acquire::Check-Valid-Until=false
sudo apt full-upgrade -y
sudo apt autoremove -y
log "System up to date"

# ── 3. Core Build Tools ───────────────────────────────────────────────────────
section "Core Build Tools"
sudo apt install -y \
    build-essential \
    curl \
    wget \
    git \
    git-lfs \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    xclip \
    xdg-utils
log "Core tools installed"

# ── 3b. Node.js + npm (via NodeSource LTS) ──────────────────────────────────
# Installs current LTS via NodeSource — much newer than the apt default.
section "Node.js + npm"
if ! command -v node &>/dev/null; then
    TMP_NODESRC=$(mktemp --suffix=.sh)
    _TMPFILES+=("$TMP_NODESRC")
    curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$TMP_NODESRC"
    sudo -E bash "$TMP_NODESRC"
    rm -f "$TMP_NODESRC"
    sudo apt install -y nodejs
    log "Node.js installed: $(node --version)  npm: $(npm --version)"

    # npm global path — avoid needing sudo for global installs
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"

    # Useful global npm tools
    npm install -g \
        npx \
        prettier \
        typescript \
        ts-node \
        nodemon
    log "Global npm tools installed"
else
    warn "Node.js already installed ($(node --version)) — skipping"
fi

# Always ensure npm global path is in .bashrc and current session
export PATH="$HOME/.npm-global/bin:$PATH"
if ! grep -q "npm-global" "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# ── npm global (no sudo) ──────────────────────────────────────────────────────
export PATH="$HOME/.npm-global/bin:$PATH"
EOF
    log "npm global path added to .bashrc"
fi

# ── 4. Python Core ────────────────────────────────────────────────────────────
section "Python Core"
# uv manages Python versions — remove packages that conflict with uv
PYTHON_REDUNDANT=(python3-pip python3-venv python3-dev)
for pkg in "${PYTHON_REDUNDANT[@]}"; do
    if dpkg -l "$pkg" &>/dev/null 2>&1; then
        sudo apt remove -y "$pkg"
        log "Removed $pkg (replaced by uv)"
    fi
done

# Keep: system Python (required by system tools), Tk, and build/link deps
sudo apt install -y \
    python3 \
    python3-tk \
    libpq-dev \
    libssl-dev \
    libffi-dev
log "Python core ready (system: $(python3 --version))"
log "Python versions managed by uv — run \'uv python list\' to see available"

# ── 5. uv + Python version management ───────────────────────────────────────
# uv is the primary Python manager — handles versions, venvs, and packages.
# Miniforge/mamba is a fallback for conda-only packages (gdal, rasterio etc.)
section "uv"
if ! command -v uv &>/dev/null; then
    TMP_UV=$(mktemp --suffix=.sh)
    _TMPFILES+=("$TMP_UV")
    curl -LsSf https://astral.sh/uv/install.sh -o "$TMP_UV"
    sh "$TMP_UV"
    rm -f "$TMP_UV"
    log "uv installed"
else
    warn "uv already installed — skipping"
fi

# Always ensure uv block is in .bashrc (covers pre-installed uv case)
if ! grep -q '_UV_COMP' "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# ── uv ────────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
_UV_COMP="$HOME/.cache/uv-completion.bash"
_UV_VER=$(uv --version 2>/dev/null || echo "none")
if [[ ! -f "$_UV_COMP" ]] || ! grep -q "^# $_UV_VER" "$_UV_COMP" 2>/dev/null; then
    mkdir -p "$(dirname "$_UV_COMP")"
    { echo "# $_UV_VER"; uv generate-shell-completion bash; } > "$_UV_COMP"
fi
source "$_UV_COMP"
EOF
fi

# Source uv into current script session so it's usable immediately
export PATH="$HOME/.local/bin:$PATH"
# Also source uv env file if present (written by installer)
[[ -f "$HOME/.local/bin/env" ]] && source "$HOME/.local/bin/env"
log "uv active: $(uv --version)"
uv python install 3.12
log "Python 3.12 ready: $(uv python find 3.12)"

# ── 6. Miniforge / mamba (conda fallback) ────────────────────────────────────
# Use mamba only for packages unavailable on PyPI.
# Default workflow is uv — see .bashrc_extras for aliases.
section "Miniforge / mamba (conda fallback)"
MINIFORGE_DIR="$HOME/miniforge3"
if [[ ! -d "$MINIFORGE_DIR" ]]; then
    info "Downloading Miniforge installer..."
    TMP_MFORGE=$(mktemp --suffix=.sh)
    _TMPFILES+=("$TMP_MFORGE")
    curl -fsSL \
        "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" \
        -o "$TMP_MFORGE"
    bash "$TMP_MFORGE" -b -p "$MINIFORGE_DIR"
    rm -f "$TMP_MFORGE"
    "$MINIFORGE_DIR/bin/conda" init bash
    cat >> "$BASHRC" <<'EOF'

# ── mamba / conda (fallback for conda-only packages) ─────────────────────────
export MAMBA_ROOT_PREFIX="$HOME/miniforge3"
export CONDA_AUTO_ACTIVATE_BASE=false
EOF
    log "Miniforge installed — use mamba only for conda-only packages"
else
    warn "Miniforge already installed — skipping"
fi

# Always ensure conda init block is in .bashrc
if ! grep -q 'conda initialize' "$BASHRC"; then
    "$MINIFORGE_DIR/bin/conda" init bash
    log "conda init added to .bashrc"
fi
# Always ensure mamba shell init is in .bashrc
if ! grep -q 'mamba initialize' "$BASHRC"; then
    "$MINIFORGE_DIR/bin/mamba" shell init --shell bash --root-prefix "$MINIFORGE_DIR"
    log "mamba shell init added to .bashrc"
fi

# Source conda/mamba into current script session so they're usable immediately
CONDA_PROFILE="$HOME/miniforge3/etc/profile.d/conda.sh"
MAMBA_PROFILE="$HOME/miniforge3/etc/profile.d/mamba.sh"
export MAMBA_ROOT_PREFIX="$HOME/miniforge3"
[[ -f "$CONDA_PROFILE" ]] && source "$CONDA_PROFILE" && export CONDA_AUTO_ACTIVATE_BASE=false
[[ -f "$MAMBA_PROFILE" ]] && { set +u; source "$MAMBA_PROFILE"; set -u; } || true
command -v mamba &>/dev/null && log "mamba active: $(mamba --version | head -1)"

# ── 7. direnv — automatic environment activation ──────────────────────────────
section "direnv"
if ! command -v direnv &>/dev/null; then
    sudo apt install -y direnv
    log "direnv installed — add .envrc to any project for auto-activation"
else
    warn "direnv already installed — skipping"
fi

# Always ensure direnv hook is in .bashrc
if ! grep -q "direnv hook" "$BASHRC"; then
    cat >> "$BASHRC" <<'EOF'

# ── direnv ────────────────────────────────────────────────────────────────────
eval "$(direnv hook bash)"
EOF
    log "direnv hook added to .bashrc"
fi

# ── 8. Global Python Tools (via uv tool install) ──────────────────────────────
# These are installed as isolated global CLI tools — available everywhere,
# not tied to any project venv. Use 'uv tool list' to see installed tools.
section "Global Python Tools"

# ── Code quality ──────────────────────────────────────────────────────────────
UV_QUALITY=(
    ruff            # linter + formatter — replaces black, isort, flake8, pylint
    mypy            # static type checker
    pyright         # Microsoft type checker (alternative to mypy)
    bandit          # security linter — finds common security issues
    vulture         # finds dead/unused code
)

# ── Testing ───────────────────────────────────────────────────────────────────
# Note: pytest-cov has no CLI executable — install per-project via uv add --dev
UV_TESTING=(
    pytest          # test runner
    hypothesis      # property-based testing
    nox             # test automation across Python versions
    tox             # test automation (alternative to nox)
)

# ── Dev workflow ──────────────────────────────────────────────────────────────
UV_WORKFLOW=(
    pre-commit      # git hook manager
    cookiecutter    # project scaffolding from templates
    bump-my-version # semantic version bumping
    twine           # publish packages to PyPI
    build           # PEP 517 build frontend
)

# ── REPL and debugging ────────────────────────────────────────────────────────
# Note: pdb-plus not on PyPI — use ipdb instead
UV_REPL=(
    ipython         # enhanced Python REPL
    ptpython        # alternative REPL with auto-complete
    ipdb            # enhanced debugger (drop-in pdb replacement)
    rich-cli        # rich text/markdown/JSON in terminal
)

# ── Data and files ────────────────────────────────────────────────────────────
# Note: pyarrow has no CLI — install per-project via uv add pyarrow
UV_DATA=(
    csvkit          # csvstat, csvcut, csvsql — query CSVs like a DB
    visidata        # terminal spreadsheet/data explorer (vd command)
    duckdb-cli      # fast analytical SQL — works on CSV, Parquet, JSON
)

# ── HTTP and APIs ─────────────────────────────────────────────────────────────
UV_HTTP=(
    httpie          # friendly HTTP client (http POST example.com key=value)
    posting         # TUI API client — better than httpie for complex requests
)

# ── Docs ──────────────────────────────────────────────────────────────────────
# Note: mkdocs-material has no standalone CLI — install via uv add --dev mkdocs-material
UV_DOCS=(
    mkdocs          # project documentation site generator
)

# ── Utilities ─────────────────────────────────────────────────────────────────
# Note: pydantic and pendulum have no CLI — install per-project via uv add
UV_UTILS=(
    pipdeptree      # show dependency tree for installed packages
    pip-audit       # audit deps for known vulnerabilities
    liccheck        # check dependency licences
    typer           # build CLIs from type hints
)

# ── Install all groups ────────────────────────────────────────────────────────
ALL_UV_TOOLS=(
    "${UV_QUALITY[@]}"
    "${UV_TESTING[@]}"
    "${UV_WORKFLOW[@]}"
    "${UV_REPL[@]}"
    "${UV_DATA[@]}"
    "${UV_HTTP[@]}"
    "${UV_DOCS[@]}"
    "${UV_UTILS[@]}"
)

for tool in "${ALL_UV_TOOLS[@]}"; do
    info "Installing $tool..."
    uv tool install "$tool" 2>/dev/null && log "$tool" || warn "$tool — skipping"
done

log "Global Python tools installed — run 'uv tool list' to see all"

# ── 9a. Terminal Utilities (apt) ──────────────────────────────────────────────
section "Terminal Utilities"
sudo apt install -y \
    micro \
    nano \
    tmux \
    htop \
    tree \
    jq \
    yq \
    fzf \
    ripgrep \
    fd-find \
    bat \
    ncdu \
    tldr \
    moreutils \
    pv \
    dos2unix \
    entr \
    procps \
    lsof \
    strace \
    net-tools \
    dnsutils \
    nmap \
    rsync \
    parallel \
    bc \
    units \
    whois
log "Terminal utilities installed"

# Debian renames bat and fd — alias them
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
    log "bat aliased from batcat"
fi
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$(which fdfind)" "$HOME/.local/bin/fd"
    log "fd aliased from fdfind"
fi

# ── 9b. Modern CLI Tools (binary installs) ────────────────────────────────────
section "Modern CLI Tools"
mkdir -p "$HOME/.local/bin"

# zoxide — smarter cd
if ! command -v zoxide &>/dev/null; then
    TMP_ZOXIDE=$(mktemp --suffix=.sh)
    _TMPFILES+=("$TMP_ZOXIDE")
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh -o "$TMP_ZOXIDE"
    sh "$TMP_ZOXIDE"
    rm -f "$TMP_ZOXIDE"
    log "zoxide installed"
else
    warn "zoxide already installed — skipping"
fi

# zoxide init will be appended at the end of .bashrc (after all other tools)

# delta — better git diff
# Uses musl (statically linked) if glibc < 2.38, gnu otherwise.
# Crostini/Debian Bookworm ships glibc 2.36 — musl required there.
if ! command -v delta &>/dev/null; then
    DELTA_VER=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest \
        | jq -r '.tag_name // empty')
    [[ -z "$DELTA_VER" ]] && die "Failed to fetch delta version from GitHub API"

    # Detect glibc version — musl is safer on anything below 2.38
    GLIBC_VER=$(ldd --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+$' || echo "0.0")
    GLIBC_MAJOR=$(echo "$GLIBC_VER" | cut -d. -f1)
    GLIBC_MINOR=$(echo "$GLIBC_VER" | cut -d. -f2)

    if [[ "$GLIBC_MAJOR" -gt 2 ]] || [[ "$GLIBC_MAJOR" -eq 2 && "$GLIBC_MINOR" -ge 38 ]]; then
        DELTA_BUILD="x86_64-unknown-linux-gnu"
        info "glibc ${GLIBC_VER} detected — using gnu delta build"
    else
        DELTA_BUILD="x86_64-unknown-linux-musl"
        info "glibc ${GLIBC_VER} detected — using musl delta build (statically linked)"
    fi

    curl -fsSL \
        "https://github.com/dandavison/delta/releases/latest/download/delta-${DELTA_VER}-${DELTA_BUILD}.tar.gz" \
        | tar -xz --strip-components=1 -C "$HOME/.local/bin" \
          "delta-${DELTA_VER}-${DELTA_BUILD}/delta"
    git config --global core.pager delta
    git config --global delta.navigate true
    git config --global delta.line-numbers true
    git config --global delta.syntax-theme "Monokai Extended"
    git config --global interactive.diffFilter "delta --color-only"
    log "delta installed (${DELTA_BUILD})"
else
    # Check existing delta still works — replace with musl if glibc mismatch
    if ! delta --version &>/dev/null 2>&1; then
        warn "delta binary broken (likely glibc mismatch) — reinstalling musl build"
        rm -f "$HOME/.local/bin/delta"
        DELTA_VER=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest \
            | jq -r '.tag_name // empty')
        [[ -z "$DELTA_VER" ]] && die "Failed to fetch delta version from GitHub API"
        curl -fsSL \
            "https://github.com/dandavison/delta/releases/latest/download/delta-${DELTA_VER}-x86_64-unknown-linux-musl.tar.gz" \
            | tar -xz --strip-components=1 -C "$HOME/.local/bin" \
              "delta-${DELTA_VER}-x86_64-unknown-linux-musl/delta"
        log "delta reinstalled (musl build)"
    else
        warn "delta already installed — skipping"
    fi
fi

# duf — better df
if ! command -v duf &>/dev/null; then
    DUF_VER=$(curl -s https://api.github.com/repos/muesli/duf/releases/latest \
        | jq -r '.tag_name // empty' | sed 's/^v//')
    [[ -z "$DUF_VER" ]] && die "Failed to fetch duf version from GitHub API"
    TMP_DUF=$(mktemp --suffix=.deb)
    _TMPFILES+=("$TMP_DUF")
    curl -fsSL \
        "https://github.com/muesli/duf/releases/latest/download/duf_${DUF_VER}_linux_amd64.deb" \
        -o "$TMP_DUF"
    sudo apt install -y "$TMP_DUF" && rm -f "$TMP_DUF"
    log "duf installed"
else
    warn "duf already installed — skipping"
fi

# lazygit — terminal git UI
if ! command -v lazygit &>/dev/null; then
    LG_VER=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
        | jq -r '.tag_name // empty' | sed 's/^v//')
    [[ -z "$LG_VER" ]] && die "Failed to fetch lazygit version from GitHub API"
    curl -fsSL \
        "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_Linux_x86_64.tar.gz" \
        | tar -xz -C "$HOME/.local/bin" lazygit
    log "lazygit installed"
else
    warn "lazygit already installed — skipping"
fi

# gh — GitHub CLI
if ! command -v gh &>/dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update && sudo apt install -y gh
    log "gh installed — run: gh auth login"
else
    warn "gh already installed — skipping"
fi

# glow — markdown in terminal (via Charm apt repo)
if ! command -v glow &>/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
        | sudo tee /etc/apt/sources.list.d/charm.list > /dev/null
    sudo apt update && sudo apt install -y glow
    log "glow installed"
else
    warn "glow already installed — skipping"
fi

# hyperfine — benchmarking
if ! command -v hyperfine &>/dev/null; then
    HF_VER=$(curl -s https://api.github.com/repos/sharkdp/hyperfine/releases/latest \
        | jq -r '.tag_name // empty' | sed 's/^v//')
    [[ -z "$HF_VER" ]] && die "Failed to fetch hyperfine version from GitHub API"
    TMP_HF=$(mktemp --suffix=.deb)
    _TMPFILES+=("$TMP_HF")
    curl -fsSL \
        "https://github.com/sharkdp/hyperfine/releases/latest/download/hyperfine_${HF_VER}_amd64.deb" \
        -o "$TMP_HF"
    sudo apt install -y "$TMP_HF" && rm -f "$TMP_HF"
    log "hyperfine installed"
else
    warn "hyperfine already installed — skipping"
fi

# ── 9c. GUI Applications ──────────────────────────────────────────────────────
section "GUI Applications"
sudo apt install -y \
    gedit \
    nautilus \
    evince \
    eog \
    gnome-font-viewer \
    file-roller \
    gnome-calculator \
    gnome-system-monitor
log "GUI apps installed"

# ── 10. Git Configuration ─────────────────────────────────────────────────────
section "Git"
git lfs install
CURRENT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || true)
CURRENT_GIT_NAME=$(git config --global user.name 2>/dev/null || true)

# Read from /dev/tty directly — works even when script is run via curl | bash
if [[ -z "$CURRENT_GIT_EMAIL" ]]; then
    read -rp "  Git email address: " GIT_EMAIL < /dev/tty
    git config --global user.email "$GIT_EMAIL"
fi
if [[ -z "$CURRENT_GIT_NAME" ]]; then
    read -rp "  Git display name:  " GIT_NAME < /dev/tty
    git config --global user.name "$GIT_NAME"
fi

git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor micro
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.lg "log --oneline --graph --decorate --all"
log "Git configured"

# ── 11. SSH Key ───────────────────────────────────────────────────────────────
section "SSH Key"
SSH_KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ ! -f "$SSH_KEY" ]]; then
    # Get email — use git config if set, otherwise prompt
    # Read from /dev/tty directly so it works even when script is piped
    SSH_EMAIL=$(git config --global user.email 2>/dev/null || true)
    if [[ -z "$SSH_EMAIL" ]]; then
        echo ""
        read -rp "  Email for SSH key: " SSH_EMAIL < /dev/tty
    fi

    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY" -N ""
    log "SSH key generated"

    # Start agent and add key
    eval "$(ssh-agent -s)" > /dev/null
    ssh-add "$SSH_KEY" 2>/dev/null

    echo ""
    echo -e "  ${BOLD}Add this public key to GitHub:${RESET}"
    echo -e "  ${CYAN}https://github.com/settings/ssh/new${RESET}"
    echo ""
    cat "${SSH_KEY}.pub"
    echo ""
    warn "Run 'ssh -T git@github.com' after adding the key to verify"
else
    warn "SSH key already exists — skipping"
    # Verify key works — advise if not yet added to GitHub
    if ! ssh -T git@github.com -o StrictHostKeyChecking=accept-new 2>&1 | grep -q "successfully authenticated"; then
        warn "SSH key not yet verified with GitHub"
        info "Public key:"
        cat "${SSH_KEY}.pub"
        info "Add at: https://github.com/settings/ssh/new"
    else
        log "SSH key verified with GitHub"
    fi
fi

# ── 12. VS Code ───────────────────────────────────────────────────────────────
section "VS Code"
if ! command -v code &>/dev/null; then
    info "Downloading VS Code..."
    TMP_DEB=$(mktemp --suffix=.deb)
    _TMPFILES+=("$TMP_DEB")
    wget -qO "$TMP_DEB" \
        "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    # Pre-answer the Microsoft repo dialog non-interactively
    echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "$TMP_DEB"
    rm -f "$TMP_DEB"
    log "VS Code installed"
else
    warn "VS Code already installed — skipping"   # ← this line was missing    
fi

# ── 13. Docker ────────────────────────────────────────────────────────────────
section "Docker"
if ! command -v docker &>/dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID} ${DISTRO_CODENAME} stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    log "Docker installed — log out and back in to use without sudo"
else
    warn "Docker already installed — skipping"
fi

# ── 14. Azure CLI ─────────────────────────────────────────────────────────────
# Installs from Microsoft's apt repo. Bundles its own Python — no uv conflict.
section "Azure CLI"
if ! command -v az &>/dev/null; then
    sudo mkdir -p /etc/apt/keyrings
    curl -sLS https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor \
        | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

    # Use distro codename — falls back to bookworm for Crostini/Debian
    AZ_DIST="${DISTRO_CODENAME}"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ ${AZ_DIST} main" \
        | sudo tee /etc/apt/sources.list.d/azure-cli.list > /dev/null

    sudo apt update && sudo apt install -y azure-cli
    log "Azure CLI installed: $(az --version 2>/dev/null | head -1)"
    info "Run 'az login' to authenticate"
else
    warn "Azure CLI already installed ($(az --version 2>/dev/null | head -1)) — skipping"
fi


# ── 15. CUDA Toolkit ──────────────────────────────────────────────────────────
# CUDA requires a real NVIDIA GPU with hardware passthrough.
# Crostini uses VirGL (virtualised GPU) — CUDA is not possible there.
# This section auto-detects Crostini and skips; runs on bare-metal Linux only.
section "CUDA"

_is_crostini() {
    [[ -f /etc/cros_chroot_config ]] || \
    grep -qi "cros\|chromeos\|penguin" /proc/version 2>/dev/null || \
    [[ "$(hostname)" == "penguin" ]]
}

if _is_crostini; then
    warn "Crostini detected — CUDA requires real GPU passthrough, skipping"
    warn "For GPU ML workloads use Azure ML, Colab, or a bare-metal Linux machine"
elif ! command -v nvidia-smi &>/dev/null; then
    warn "No NVIDIA GPU detected (nvidia-smi not found) — skipping CUDA"
    warn "To install manually on a machine with an NVIDIA GPU, re-run with: INSTALL_CUDA=1 bash linux_setup.sh"
else
    # NVIDIA GPU confirmed — install CUDA toolkit
    CUDA_DISTRO="${DISTRO_ID}${DISTRO_CODENAME}"   # e.g. debian12, ubuntu22.04

    info "NVIDIA GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
    info "Installing CUDA toolkit..."

    # Add NVIDIA keyring and repo
    sudo install -m 0755 -d /etc/apt/keyrings
    TMP_CUDA_KEY=$(mktemp --suffix=.deb)
    _TMPFILES+=("$TMP_CUDA_KEY")
    curl -fsSL "https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO_ID}$(lsb_release -sr | tr -d '.')/x86_64/cuda-keyring_1.1-1_all.deb" \
        -o "$TMP_CUDA_KEY" 2>/dev/null \
    && sudo apt install -y "$TMP_CUDA_KEY" \
    && rm -f "$TMP_CUDA_KEY" \
    || {
        warn "CUDA repo setup failed — check https://developer.nvidia.com/cuda-downloads for manual install"
    }

    sudo apt update
    # Install toolkit only (not drivers — those should already be installed)
    sudo apt install -y cuda-toolkit
    log "CUDA toolkit installed: $(nvcc --version 2>/dev/null | grep -oP 'release \K[\d.]+' || echo 'unknown')"

    # Add CUDA to PATH
    if ! grep -q "cuda" "$BASHRC"; then
        cat >> "$BASHRC" <<'EOF'

# ── CUDA ──────────────────────────────────────────────────────────────────────
export PATH="/usr/local/cuda/bin:$PATH"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:$LD_LIBRARY_PATH"
EOF
        export PATH="/usr/local/cuda/bin:$PATH"
        export LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
        log "CUDA paths added to .bashrc"
    fi

    # Verify
    if command -v nvcc &>/dev/null; then
        log "CUDA ready: $(nvcc --version 2>/dev/null | grep release)"
        log "GPU: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null)"
    fi
fi


# ── Zoxide init (must be last in .bashrc) ────────────────────────────────────
# Remove any existing zoxide block, then re-append so it stays after conda/mamba
sed -i '/# ── zoxide (smart cd)/,/alias cd=.z./d' "$BASHRC"
cat >> "$BASHRC" <<'EOF'

# ── zoxide (smart cd) ─────────────────────────────────────────────────────────
eval "$(zoxide init bash)"
alias cd='z'
EOF
log "zoxide init placed at end of .bashrc"

# ── Done ──────────────────────────────────────────────────────────────────────
section "Core Setup Complete"
echo -e "${GREEN}${BOLD}"
echo "  ✔ System updated + sources cleaned"
echo "  ✔ Python + uv + mamba (miniforge) + dev tools"
echo "  ✔ Terminal utilities (fzf, ripgrep, bat, micro, tmux, zoxide, delta...)"
echo "  ✔ Modern CLI tools (lazygit, gh, glow, duf, hyperfine, csvkit)"
echo "  ✔ GUI apps (gedit, nautilus, evince, eog, file-roller, calculator)"
echo "  ✔ Git configured + SSH key"
echo "  ✔ VS Code installed"
echo "  ✔ Docker installed"
echo -e "${RESET}"
