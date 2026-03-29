# linux_setup

Automated Python dev environment setup for Chromebook (Crostini) and any Debian/Ubuntu machine.

---

## Quick Start

### Chromebook
```bash
curl -fsSL https://raw.githubusercontent.com/romhom/linux_setup/main/bootstrap.sh | bash
```

### Any Debian/Ubuntu machine
```bash
curl -fsSL https://raw.githubusercontent.com/romhom/linux_setup/main/linux_setup.sh | bash
```

### Terminal config (run after either of the above)
```bash
bash ~/linux_setup/terminal_setup.sh
```

---

## Scripts

| Script | Purpose | Run on |
|--------|---------|--------|
| `bootstrap.sh` | Downloads all scripts and configs, then runs `chromebook_setup.sh` | Chromebook only |
| `chromebook_setup.sh` | Orchestrator — calls `linux_setup.sh` then `chromebook_crostini.sh` | Chromebook only |
| `linux_setup.sh` | Portable core — Python, tools, Git, Docker, Azure CLI | Any Debian/Ubuntu |
| `chromebook_crostini.sh` | Crostini extras — display fix, gedit-sudo wrapper | Chromebook only |
| `terminal_setup.sh` | Starship prompt, bash config, tmux, editor configs | Any machine |
| `update.sh` | Re-fetches latest scripts and configs from GitHub, re-applies configs | Any machine |

All scripts are **idempotent** — safe to re-run, skips anything already installed.

---

## What Gets Installed

### Core (`linux_setup.sh`)

**System**
- Build tools, curl, wget, git, git-lfs, CA certs
- Node.js LTS + npm (via NodeSource), global tools: prettier, typescript, ts-node, nodemon

**Python**
- System Python 3 (build deps only — python3-pip/venv/dev removed to avoid uv conflicts)
- **uv** — primary Python manager: versions, venvs, packages (replaces pip, pipx, poetry, pyenv)
- **Miniforge** — mamba + conda as fallback for conda-only packages (gdal, rasterio etc.)
- **direnv** — automatic venv activation per project directory
- Python 3.12 installed via uv

**Global Python tools** (via `uv tool install`)
- Code quality: `ruff`, `mypy`, `pyright`, `bandit`, `vulture`
- Testing: `pytest`, `hypothesis`, `nox`, `tox`
- Dev workflow: `pre-commit`, `cookiecutter`, `bump-my-version`, `twine`, `build`
- REPL/debug: `ipython`, `ptpython`, `ipdb`, `rich-cli`
- Data: `csvkit`, `visidata`, `duckdb-cli`
- HTTP/API: `httpie`, `posting`
- Docs: `mkdocs`
- Utilities: `pipdeptree`, `pip-audit`, `liccheck`, `typer`

**Terminal utilities**
- `fzf`, `ripgrep`, `bat`, `fd`, `ncdu`, `tmux`, `micro`, `nano`, `htop`, `tree`
- `jq`, `yq`, `pv`, `entr`, `parallel`, `dos2unix`, `strace`, `nmap`, and more

**Modern CLI tools**
- `zoxide` (smart cd), `delta` (git diff), `lazygit` (git TUI), `gh` (GitHub CLI)
- `glow` (markdown), `duf` (disk usage), `hyperfine` (benchmarking)

**GUI apps** — `gedit`, `nautilus`, `evince`, `eog`, `file-roller`, `gnome-calculator`

**Dev tools**
- Git — configured with sensible defaults, delta as diff pager
- SSH — ed25519 key generated if not present
- VS Code — installed from official `.deb`
- Docker CE — from Docker's own repo, user added to docker group
- Azure CLI — from Microsoft's apt repo
- CUDA toolkit — auto-detected; skipped on Crostini (no GPU passthrough), installs on bare-metal with NVIDIA GPU

### Crostini extras (`chromebook_crostini.sh`)
- Display protocol fix (`DISPLAY=:0`, `XAUTHORITY`) so `sudo gedit` works
- `sudoers` passthrough for GUI apps under sudo
- `gedit-sudo` wrapper

### Terminal (`terminal_setup.sh`)
- **Starship** — prompt showing git branch/status, Python version, conda/mamba env, command duration
- **JetBrainsMono Nerd Font** — required for Starship symbols
- **`.bashrc_extras`** — aliases, functions, fzf config, SSH agent persistence, history settings
- **tmux** — configured with tpm, session persistence (resurrect + continuum), Catppuccin status bar
- **nano** and **micro** — configs applied from repo

---

## Repo Structure

```
linux_setup/
├── README.md
├── bootstrap.sh               ← Chromebook one-liner entry point
├── chromebook_setup.sh        ← Chromebook orchestrator
├── linux_setup.sh             ← Portable core (any Debian/Ubuntu)
├── chromebook_crostini.sh     ← Crostini-specific extras
├── terminal_setup.sh          ← Prompt + terminal config
├── update.sh                  ← Sync latest from GitHub
└── configs/
    ├── starship.toml          ← Starship prompt config
    ├── .bashrc_extras         ← Aliases, functions, exports
    ├── tmux.conf              ← tmux config + plugins
    ├── .nanorc                ← nano config
    └── micro_settings.json    ← micro editor config
```

---

## Updating Your Setup

### Update everything on a machine
```bash
setup-update
```
Pulls latest scripts and configs from GitHub, applies them, reloads tmux if running. Then:
```bash
reload
```

### After changing a script or config
```bash
cd ~/linux_setup
micro configs/.bashrc_extras   # or whichever file
git add . && git commit -m "describe change"
git push
```
Then on any other machine:
```bash
setup-update && reload
```

### Applying setup changes to an existing machine
```bash
# Safe to re-run — skips already-installed tools
bash ~/linux_setup/linux_setup.sh
bash ~/linux_setup/terminal_setup.sh
```

### Fresh Chromebook
```bash
curl -fsSL https://raw.githubusercontent.com/romhom/linux_setup/main/bootstrap.sh | bash
```

---

## First Time — Push to GitHub

```bash
# Auth GitHub CLI
gh auth login

# The repo already exists at github.com/romhom/linux_setup
cd ~/linux_setup
git init
git add .
git commit -m "initial commit"
git remote add origin git@github.com:romhom/linux_setup.git
git push -u origin main
```

---

## Useful Commands After Setup

```bash
# New Python project (full scaffold)
mkpy my-project               # pyproject.toml, ruff, mypy, pre-commit, Makefile, tests/

# Python environment
uv add requests               # add dependency
uv sync                       # sync env to lockfile
uv run pytest                 # run in project env
uvpl                          # list available Python versions

# Mamba (conda fallback — for packages not on PyPI only)
mamba create -n myenv python=3.12
mamba activate myenv

# Git
lg                            # lazygit TUI
glog                          # pretty log

# Navigation
z proj                        # zoxide jump to most-used dir
crdl                          # jump to ChromeOS Downloads

# Data
vd data.csv                   # visidata TUI spreadsheet
duck                          # duckdb SQL shell

# tmux
tn work                       # new session named 'work'
ta                            # attach to last session
# prefix = Ctrl+a
# prefix + |   split vertical
# prefix + -   split horizontal
# prefix + I   install plugins (first run only)

# System
up                            # update apt + uv tools + setup scripts in one go
myip                          # external IP
weather                       # terminal weather
pyinfo                        # Python environment summary
```
