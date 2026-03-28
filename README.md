# chromebook-setup

Automated Python dev environment setup for Chromebook (Crostini) and any Debian/Ubuntu machine.

---

## Quick Start

### Chromebook
```bash
# Download all scripts (all three needed)
curl -fsSL https://raw.githubusercontent.com/romhom/chromebook-setup/main/chromebook_setup.sh -o chromebook_setup.sh
curl -fsSL https://raw.githubusercontent.com/romhom/chromebook-setup/main/linux_setup.sh -o linux_setup.sh
curl -fsSL https://raw.githubusercontent.com/romhom/chromebook-setup/main/chromebook_crostini.sh -o chromebook_crostini.sh

bash chromebook_setup.sh
```

### Any Debian/Ubuntu machine
```bash
curl -fsSL https://raw.githubusercontent.com/romhom/chromebook-setup/main/linux_setup.sh | bash
```

### Terminal config (run after either of the above)
```bash
curl -fsSL https://raw.githubusercontent.com/romhom/chromebook-setup/main/terminal_setup.sh | bash
```

> **Note:** Update `REPO_RAW` at the top of `terminal_setup.sh` to point at your own repo before running.

---

## Scripts

| Script | Purpose | Run on |
|--------|---------|--------|
| `chromebook_setup.sh` | Orchestrator — calls `linux_setup.sh` then `chromebook_crostini.sh` | Chromebook only |
| `linux_setup.sh` | Portable core — Python, tools, Git, Docker | Any Debian/Ubuntu |
| `chromebook_crostini.sh` | Crostini extras — display fix, ChromeOS aliases | Chromebook only |
| `terminal_setup.sh` | Starship, bash config, tmux, editor configs | Any machine |

All scripts are **idempotent** — safe to re-run, skips anything already installed.

---

## What Gets Installed

### Core (`linux_setup.sh`)
- **System** — build tools, curl, wget, git, git-lfs, CA certs
- **Python** — Python 3 + dev headers
- **uv** — fast Python package and project manager (replaces pip/pipx)
- **Miniforge** — mamba + conda for environment management
- **Python dev tools** via uv: `black`, `isort`, `ruff`, `mypy`, `pytest`, `ipython`, `poetry`, `pre-commit`, `cookiecutter`, `httpie`
- **Common packages** — numpy, pandas, matplotlib, scipy, jupyter, pydantic, rich, loguru
- **Terminal utilities** — `fzf`, `ripgrep`, `bat`, `fd`, `ncdu`, `tmux`, `micro`, `nano`, `htop`, `tree`, `jq`, `pv`, `entr`, `parallel`, and more
- **Modern CLI tools** — `zoxide`, `delta`, `lazygit`, `gh`, `glow`, `duf`, `hyperfine`, `csvkit`
- **GUI apps** — `gedit`, `nautilus`, `evince`, `eog`, `file-roller`, `gnome-calculator`
- **Git** — configured with sensible defaults, delta as diff pager
- **SSH** — ed25519 key generated if not present
- **VS Code** — installed from official `.deb`
- **Docker** — CE from Docker's own repo, user added to docker group

### Crostini extras (`chromebook_crostini.sh`)
- Display protocol fix (`DISPLAY=:0`, `XAUTHORITY`) so `sudo gedit` works
- `sudoers` passthrough for GUI apps under sudo
- `gedit-sudo` wrapper
- ChromeOS path aliases: `crdl`, `crfiles`, `crgdrive`

### Terminal (`terminal_setup.sh`)
- **Starship** — prompt showing git status, Python version, conda env, command duration
- **JetBrainsMono Nerd Font** — required for Starship symbols
- **`.bashrc_extras`** — aliases, functions, fzf config, history settings
- **tmux** — configured with tpm, session persistence (resurrect + continuum)
- **nano** and **micro** — configs applied

---

## Repo Structure

```
chromebook-setup/
├── README.md
├── chromebook_setup.sh        ← Chromebook entry point
├── linux_setup.sh             ← Portable core
├── chromebook_crostini.sh     ← Crostini extras
├── terminal_setup.sh          ← Prompt + terminal config
└── configs/
    ├── starship.toml          ← Starship prompt config
    ├── .bashrc_extras         ← Aliases, functions, exports
    ├── tmux.conf              ← tmux config + plugins
    ├── .nanorc                ← nano config
    └── micro_settings.json   ← micro editor config
```

---

## Workflow

### After initial setup on a new Chromebook

```bash
# Auth GitHub
gh auth login

# Create the repo (first time only)
gh repo create chromebook-setup --public

# Push
mkdir ~/chromebook-setup && cd ~/chromebook-setup
git init
# copy scripts and configs in, then:
git add . && git commit -m "initial"
git remote add origin git@github.com:romhom/chromebook-setup.git
git push -u origin main
```

### Updating the setup

```bash
cd ~/chromebook-setup
micro linux_setup.sh        # or whichever file needs changing
git add . && git commit -m "add xyz"
git push
```

### Applying updates to an existing machine

```bash
# Re-run is safe — skips already-installed tools
bash ~/chromebook-setup/linux_setup.sh
bash ~/chromebook-setup/terminal_setup.sh
```

---

## Useful Commands After Setup

```bash
# Python environment
mamba create -n myenv python=3.12   # new conda env
mamba activate myenv
uv pip install pandas numpy         # fast installs

# New Python project
mkpy my-project                     # scaffolds dir, venv, git init

# Git
lg                                  # open lazygit TUI
glog                                # pretty git log

# Navigation
z proj                              # zoxide jump to most-used 'proj' dir
crdl                                # jump to ChromeOS Downloads

# tmux
tmux new -s work                    # new session named 'work'
# prefix = Ctrl+a
# prefix + |  split vertical
# prefix + -  split horizontal
# prefix + I  install plugins (first run)
```
