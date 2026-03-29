# linux_setup

Automated Python dev environment setup for Chromebook (Crostini) and any Debian/Ubuntu machine.

---

## Quick Start

**One command — works on Chromebook and any Debian/Ubuntu machine:**
```bash
curl -fsSL https://raw.githubusercontent.com/romhom/linux_setup/main/install.sh | bash
```

Platform is auto-detected. On Chromebook, Crostini-specific config is applied automatically.

---

## What it does

1. Downloads all scripts and configs to `~/linux_setup/`
2. Runs core setup — Python, tools, Git, Docker, Azure CLI
3. Applies Crostini extras if on a Chromebook (auto-detected)
4. Configures terminal — Starship prompt, tmux, aliases, editor configs

After install:
```bash
source ~/.bashrc       # apply shell config
gh auth login          # authenticate GitHub
ssh -T git@github.com  # verify SSH key
```

---

## Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` | Single entry point — auto-detects platform, runs everything |
| `linux_setup.sh` | Portable core — Python, tools, Git, Docker, Azure CLI |
| `chromebook_crostini.sh` | Crostini extras — display fix, gedit-sudo wrapper |
| `terminal_setup.sh` | Starship prompt, bash config, tmux, editor configs |
| `update.sh` | Re-fetches latest scripts and configs from GitHub |

All scripts are **idempotent** — safe to re-run, skips anything already installed.

**Re-run options:**
```bash
# Re-run everything (ignores saved progress)
bash ~/linux_setup/install.sh --skip-checkpoints

# Re-run a single stage only
bash ~/linux_setup/install.sh --only core
bash ~/linux_setup/install.sh --only terminal
bash ~/linux_setup/install.sh --only crostini

# Check what's installed without running anything
setup-check
```

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
- CUDA toolkit — auto-detected; skipped on Crostini, installs on bare-metal with NVIDIA GPU

### Crostini extras (`chromebook_crostini.sh`)
- Display protocol fix (`DISPLAY=:0`, `XAUTHORITY`) so `sudo gedit` works
- `sudoers` passthrough for GUI apps under sudo
- `gedit-sudo` wrapper

### Terminal (`terminal_setup.sh`)
- **Starship** — prompt showing git branch/status, Python version, conda/mamba env, command duration
- Simple fallback config for Chromebook (no Nerd Font required); full config via `prompt-nerd`
- **JetBrainsMono Nerd Font** — installed to Linux fonts directory
- **`.bashrc_extras`** — aliases, functions, fzf config, SSH agent persistence, history settings
- **tmux** — configured with tpm, session persistence (resurrect + continuum)
- **nano** and **micro** — configs applied from repo

---

## Repo Structure

```
linux_setup/
├── README.md
├── install.sh                 ← single entry point (Chromebook + Linux)
├── linux_setup.sh             ← portable core (any Debian/Ubuntu)
├── chromebook_crostini.sh     ← Crostini-specific extras
├── terminal_setup.sh          ← prompt + terminal config
├── update.sh                  ← sync latest from GitHub
└── configs/
    ├── starship.toml          ← Starship prompt config (Nerd Font)
    ├── starship_simple.toml   ← Starship fallback (any font)
    ├── .bashrc_extras         ← aliases, functions, exports
    ├── tmux.conf              ← tmux config + plugins
    ├── .nanorc                ← nano config
    └── micro_settings.json    ← micro editor config
```

---

## Updating Your Setup

### Update everything on a machine
```bash
setup-update && reload
```

### After changing a script or config
```bash
cd ~/linux_setup
micro configs/.bashrc_extras   # or whichever file
git add . && git commit -m "describe change"
git push
```
Then on any other machine: `setup-update && reload`

### Fresh machine
```bash
curl -fsSL https://raw.githubusercontent.com/romhom/linux_setup/main/install.sh | bash
```

---

## Useful Commands After Setup

```bash
# Health check
setup-check                   # verify all tools installed correctly

# New Python project
mkpy my-project               # full scaffold: pyproject.toml, ruff, mypy, pre-commit, Makefile

# Python
uv add requests               # add dependency
uv sync                       # sync env to lockfile
uv run pytest                 # run in project env

# Git
lg                            # lazygit TUI
glog                          # pretty log

# Navigation
z proj                        # zoxide jump to most-used dir
crdl                          # jump to ChromeOS Downloads (Chromebook)

# tmux
tn work                       # new session named 'work'
ta                            # attach to last session
# prefix = Ctrl+a  |  prefix+|  split  |  prefix+I  install plugins

# Prompt (Chromebook)
prompt-nerd                   # switch to Nerd Font prompt
prompt-simple                 # switch to plain prompt

# System
up                            # update everything
setup-update                  # sync setup scripts from GitHub
pyinfo                        # Python environment summary
```
