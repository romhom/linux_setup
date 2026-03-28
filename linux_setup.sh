#!/usr/bin/env bash
# =============================================================================
# Linux Core Setup — Debian/Ubuntu Python Dev Environment
# Portable: works on any Debian/Ubuntu based machine
# Called directly or via chromebook_setup.sh
# =============================================================================
set -euo pipefail

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

# ── 4. Python Core ────────────────────────────────────────────────────────────
section "Python Core"
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-tk \
    libpq-dev \
    libssl-dev \
    libffi-dev
log "Python 3 installed: $(python3 --version)"

# ── 5. uv ─────────────────────────────────────────────────────────────────────
section "uv"
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    cat >> "$BASHRC" <<'EOF'

# ── uv ────────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$PATH"
eval "$(uv generate-shell-completion bash)"
EOF
    export PATH="$HOME/.local/bin:$PATH"
    log "uv installed: $(uv --version)"
else
    warn "uv already installed — skipping"
fi

# ── 6. Miniforge / mamba ──────────────────────────────────────────────────────
section "Miniforge / mamba"
MINIFORGE_DIR="$HOME/miniforge3"
if [[ ! -d "$MINIFORGE_DIR" ]]; then
    info "Downloading Miniforge installer..."
    TMP_MFORGE=$(mktemp /tmp/miniforge-XXXX.sh)
    curl -fsSL \
        "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" \
        -o "$TMP_MFORGE"
    bash "$TMP_MFORGE" -b -p "$MINIFORGE_DIR"
    rm -f "$TMP_MFORGE"
    "$MINIFORGE_DIR/bin/conda" init bash
    cat >> "$BASHRC" <<'EOF'

# ── mamba / conda ─────────────────────────────────────────────────────────────
export CONDA_AUTO_ACTIVATE_BASE=false
EOF
    log "Miniforge installed — mamba and conda available after terminal restart"
    log "Usage: mamba create -n myenv python=3.12 && mamba activate myenv"
else
    warn "Miniforge already installed — skipping"
fi

# ── 7. Python Dev Tools (via uv) ──────────────────────────────────────────────
section "Python Dev Tools"
export PATH="$HOME/.local/bin:$PATH"

UV_TOOLS=(
    black          # formatter
    isort          # import sorter
    ruff           # fast linter
    mypy           # type checker
    pytest         # testing
    ipython        # enhanced REPL
    poetry         # dependency management
    pre-commit     # git hook manager
    cookiecutter   # project templates
    httpie         # HTTP client
)
for tool in "${UV_TOOLS[@]}"; do
    info "Installing $tool..."
    uv tool install "$tool" 2>/dev/null && log "$tool" || warn "$tool failed — skipping"
done

# ── 8. Common Python Packages ─────────────────────────────────────────────────
section "Common Python Packages"
uv pip install --system \
    requests numpy pandas matplotlib scipy \
    jupyter notebook ipykernel \
    python-dotenv pydantic rich typer loguru \
    2>/dev/null || \
uv pip install \
    requests numpy pandas matplotlib scipy \
    jupyter notebook ipykernel \
    python-dotenv pydantic rich typer loguru
log "Common packages installed"

# ── 9a. Terminal Utilities (apt) ──────────────────────────────────────────────
section "Terminal Utilities"
sudo apt install -y \
    micro \
    nano \
    tmux \
    htop \
    tree \
    jq \
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
    watch \
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
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    cat >> "$BASHRC" <<'EOF'

# ── zoxide (smart cd) ─────────────────────────────────────────────────────────
eval "$(zoxide init bash)"
alias cd='z'
EOF
    log "zoxide installed"
else
    warn "zoxide already installed — skipping"
fi

# delta — better git diff
if ! command -v delta &>/dev/null; then
    DELTA_VER=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest \
        | grep tag_name | cut -d'"' -f4)
    curl -fsSL \
        "https://github.com/dandavison/delta/releases/latest/download/delta-${DELTA_VER}-x86_64-unknown-linux-gnu.tar.gz" \
        | tar -xz --strip-components=1 -C "$HOME/.local/bin" \
          "delta-${DELTA_VER}-x86_64-unknown-linux-gnu/delta"
    git config --global core.pager delta
    git config --global delta.navigate true
    git config --global delta.line-numbers true
    git config --global delta.syntax-theme "Monokai Extended"
    git config --global interactive.diffFilter "delta --color-only"
    log "delta installed"
else
    warn "delta already installed — skipping"
fi

# duf — better df
if ! command -v duf &>/dev/null; then
    DUF_VER=$(curl -s https://api.github.com/repos/muesli/duf/releases/latest \
        | grep tag_name | cut -d'"' -f4 | tr -d 'v')
    curl -fsSL \
        "https://github.com/muesli/duf/releases/latest/download/duf_${DUF_VER}_linux_amd64.deb" \
        -o /tmp/duf.deb
    sudo apt install -y /tmp/duf.deb && rm /tmp/duf.deb
    log "duf installed"
else
    warn "duf already installed — skipping"
fi

# lazygit — terminal git UI
if ! command -v lazygit &>/dev/null; then
    LG_VER=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
        | grep tag_name | cut -d'"' -f4 | tr -d 'v')
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
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update && sudo apt install -y gh
    log "gh installed — run: gh auth login"
else
    warn "gh already installed — skipping"
fi

# glow — markdown in terminal
if ! command -v glow &>/dev/null; then
    curl -fsSL \
        "https://github.com/charmbracelet/glow/releases/latest/download/glow_Linux_x86_64.tar.gz" \
        | tar -xz -C "$HOME/.local/bin" glow
    log "glow installed"
else
    warn "glow already installed — skipping"
fi

# hyperfine — benchmarking
if ! command -v hyperfine &>/dev/null; then
    HF_VER=$(curl -s https://api.github.com/repos/sharkdp/hyperfine/releases/latest \
        | grep tag_name | cut -d'"' -f4 | tr -d 'v')
    curl -fsSL \
        "https://github.com/sharkdp/hyperfine/releases/latest/download/hyperfine_${HF_VER}_amd64.deb" \
        -o /tmp/hyperfine.deb
    sudo apt install -y /tmp/hyperfine.deb && rm /tmp/hyperfine.deb
    log "hyperfine installed"
else
    warn "hyperfine already installed — skipping"
fi

# csvkit — CSV tooling
uv tool install csvkit 2>/dev/null && log "csvkit installed" || warn "csvkit failed — skipping"

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

if [[ -z "$CURRENT_GIT_EMAIL" ]]; then
    read -rp "  Git email address: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi
if [[ -z "$CURRENT_GIT_NAME" ]]; then
    read -rp "  Git display name:  " GIT_NAME
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
if [[ ! -f "$SSH_KEY" ]]; then
    GIT_EMAIL=$(git config --global user.email)
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY"
    echo ""
    warn "Add this public key to GitHub/GitLab:"
    echo ""
    cat "${SSH_KEY}.pub"
    echo ""
else
    warn "SSH key already exists — skipping"
fi

# ── 12. VS Code ───────────────────────────────────────────────────────────────
section "VS Code"
if ! command -v code &>/dev/null; then
    info "Downloading VS Code..."
    TMP_DEB=$(mktemp /tmp/vscode-XXXX.deb)
    wget -qO "$TMP_DEB" \
        "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
    sudo apt install -y "$TMP_DEB"
    rm -f "$TMP_DEB"
    log "VS Code installed"
else
    warn "VS Code already installed — skipping"
fi

# ── 13. Docker ────────────────────────────────────────────────────────────────
section "Docker"
if ! command -v docker &>/dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/${DISTRO_ID} ${DISTRO_CODENAME} stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    log "Docker installed — log out and back in to use without sudo"
else
    warn "Docker already installed — skipping"
fi

# ── 14. Editor Config ─────────────────────────────────────────────────────────
section "Editor Config"

cat > "$HOME/.nanorc" <<'EOF'
set mouse
set linenumbers
set autoindent
set tabsize 4
set tabstospaces
set softwrap
set titlebar
set constantshow
include "/usr/share/nano/*.nanorc"
EOF
log "nano configured"

MICRO_CFG="$HOME/.config/micro"
mkdir -p "$MICRO_CFG"
cat > "$MICRO_CFG/settings.json" <<'EOF'
{
    "tabsize": 4,
    "tabstospaces": true,
    "autoindent": true,
    "mouse": true,
    "ruler": true,
    "softwrap": true,
    "colorscheme": "monokai"
}
EOF
log "micro configured"

# ── 15. PATH ──────────────────────────────────────────────────────────────────
section "PATH"
if ! grep -q '\.local/bin' "$BASHRC"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
    log ".local/bin added to PATH"
fi

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
