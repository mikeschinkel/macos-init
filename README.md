# macos-init

Infrastructure-as-Code for macOS shell configuration. Clone to `~/.init`, create a few shim dotfiles, and your shell environment is version-controlled, portable, and repeatable.

> **Status:** This repo is a work in progress. The architecture and patterns (shim dotfiles, modular rc.d, secrets management) are designed to be reusable, but the configuration values are currently specific to my machine. Over time I intend to evolve this into a generically usable solution — likely with a Go-based CLI and a Justfile — so that anyone can clone it, run a setup command, and get a clean, personalized shell environment. Contributions and feedback are welcome.

## Quick Start

```bash
# 1. Clone
git clone https://github.com/mikeschinkel/macos-init.git ~/.init

# 2. Create shim dotfiles
cat > ~/.zshenv  << 'EOF'
[ -r "$HOME/.init/zsh/zshenv" ] && . "$HOME/.init/zsh/zshenv"
EOF

cat > ~/.zprofile << 'EOF'
[ -r "$HOME/.init/zsh/zprofile" ] && . "$HOME/.init/zsh/zprofile"
EOF

cat > ~/.zshrc << 'EOF'
[ -r "$HOME/.init/zsh/zshrc" ] && . "$HOME/.init/zsh/zshrc"
EOF

# 3. Install Homebrew packages
brew bundle --file=~/.init/Brewfile

# 4. Set up secrets (optional)
cp ~/.init/.secrets.sample.json ~/.init/.secrets.json
# Edit .secrets.json with your actual values

# 5. Reload
source ~/.zshrc
```

## How It Works

Your top-level dotfiles (`~/.zshrc`, `~/.zshenv`, `~/.zprofile`) become one-line shims that delegate to files in `~/.init/zsh/`. All real configuration lives here, under version control.

```
~/.zshenv    →  ~/.init/zsh/zshenv      (environment variables, quiet, no output)
~/.zprofile  →  ~/.init/zsh/zprofile    (login-time setup: Homebrew shellenv)
~/.zshrc     →  ~/.init/zsh/zshrc       (interactive: aliases, prompt, completions)
```

See [ADR-002](adrs/adr-002-shell-and-dotfiles-architecture.md) for the full rationale.

## Directory Structure

```
~/.init/
├── zsh/                          # Zsh configuration
│   ├── zshenv                    # Environment variables (all shells)
│   ├── zprofile                  # Login shell setup (Homebrew)
│   ├── zshrc                     # Interactive config (aliases, prompt)
│   └── rc.d/                     # Modular interactive config
│       ├── 10-functions.zsh      # Shell functions
│       ├── 20-completion-paths.zsh
│       ├── 50-history-tools.zsh
│       └── 90-compinit.zsh       # Completion init (must be last)
├── scripts/
│   └── common.sh                 # Shared functions (Zsh + Bash compatible)
├── bin/                          # Custom utilities (added to PATH)
│   ├── secret                    # Read values from .secrets.json
│   ├── ssh, scp                  # SSH wrappers with logging
│   ├── gobrew, godoc             # Go utilities
│   ├── clean-go-dir              # Go workspace cleanup
│   └── timeout                   # timeout shim for macOS
├── tmux/                         # Tmux configuration
│   ├── tmux.conf                 # Main config (sources conf.d/)
│   ├── conf.d/                   # Modular tmux config
│   └── scripts/                  # Tmux helper scripts
├── setup/                        # One-time setup scripts (run manually)
├── adrs/                         # Architecture Decision Records
├── docs/                         # Additional documentation
├── Brewfile                      # Homebrew package manifest
├── .secrets.json                 # Your secrets (gitignored)
└── .secrets.sample.json          # Template for .secrets.json
```

## Secrets Management

Secrets are stored in `.secrets.json` (gitignored, never committed) and accessed at runtime via the `secret` utility:

```bash
# .secrets.json format:
{ "GORELEASER_KEY": "your-key-here", "GITHUB_TOKEN": "ghp_..." }

# Usage in scripts:
secret GORELEASER_KEY    # prints the value
```

Environment variables that need secrets use command substitution in `zshrc`, so no actual values appear in tracked files:

```bash
export GORELEASER_KEY="$(secret GORELEASER_KEY)"
```

## Key Features

### Go Toolchain Management

Switch between multiple Go versions installed under `~/go/sdk/`:

```bash
go_use default    # Homebrew Go (arm64)
go_use 1.25.3     # ~/go/sdk/go1.25.3
go_list           # Show all installed toolchains
```

See [ADR-001](adrs/adr-001-go-toolchains-on-m4-macmini.md) for details.

### Binary Architecture Utilities

Tools for managing the Intel-to-ARM migration on Apple Silicon:

```bash
bin_arch go           # Show architecture of a CLI binary
app_arch Safari       # Show architecture of a macOS app
audit_x86             # Scan directories for x86-only binaries
reinstall_x86_casks   # Interactively upgrade x86 Homebrew casks to arm64
reinstall_x86_bins    # Interactively migrate x86 Homebrew binaries to arm64
```

### Modular Zsh Config

Interactive configuration is split into numbered modules under `zsh/rc.d/`:

| File | Purpose |
|------|---------|
| `10-functions.zsh` | Shell functions |
| `20-completion-paths.zsh` | Completion paths (Docker, Homebrew) |
| `50-history-tools.zsh` | History configuration |
| `90-compinit.zsh` | `compinit` call (must be last) |

See [zsh/ARCHITECTURE.md](zsh/ARCHITECTURE.md) for ordering rules and invariants.

## Customizing for Your Own Use

To fork this for your own machine:

1. Fork/clone the repo
2. Edit `zsh/zshenv` with your environment variables
3. Edit `zsh/zshrc` with your aliases and preferences
4. Replace `Brewfile` with your own package list (`brew bundle dump`)
5. Create `.secrets.json` from the sample with your own keys
6. Remove or update the `adrs/` entries to reflect your own decisions

The architecture (shim dotfiles, modular rc.d, secrets management) is designed to be reusable regardless of the specific configuration values.

## Requirements

- macOS (designed for Apple Silicon, works on Intel)
- Zsh (macOS default since Catalina)
- [Homebrew](https://brew.sh)
- `jq` (for the `secret` utility; install via `brew install jq`)

## License

MIT
