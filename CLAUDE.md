# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **macOS shell configuration repository** (`~/.init`) that implements Infrastructure-as-Code principles for shell environment setup. It centralizes all shell configuration files, scripts, and utilities in a version-controlled directory.

## Architecture

### Core Design Principles

The repository follows **ADR-002: Shell & Dotfiles Architecture**:

1. **Single source of truth**: All shell configuration lives under `~/.init`
2. **Thin shim dotfiles**: Top-level dotfiles (`~/.zshrc`, `~/.zshenv`, `~/.zprofile`) are minimal and simply source files from `~/.init/zsh/`
3. **Shared helpers**: Shell functions usable across both Zsh and Bash live in `~/.init/scripts/common.sh`
4. **Separation of concerns**:
   - `zsh/zshenv`: Global environment variables (quiet, no output)
   - `zsh/zprofile`: Login-time setup (Homebrew shellenv)
   - `zsh/zshrc`: Interactive configuration (aliases, prompt, sourcing common.sh)

### Directory Structure

```
~/.init/
├── zsh/                      # Zsh configuration
│   ├── zshenv                # Environment variables
│   ├── zprofile              # Login shell setup
│   └── zshrc                 # Interactive shell config
├── scripts/
│   └── common.sh             # Shared shell functions (Zsh/Bash compatible)
├── bin/                      # Custom utilities
│   ├── secret                # Retrieves secrets from .secrets.json
│   ├── ssh, scp             # Custom SSH wrappers
│   ├── timeout               # timeout shim
│   └── clean-go-dir, gobrew, godoc  # Go-related utilities
├── setup/                    # Setup scripts (work in progress)
├── adrs/                     # Architecture Decision Records
└── docs/                     # Documentation
```

## Go Toolchain Management

This repository implements **ADR-001: Managing Multiple Go Toolchains**:

### Directory Layout
- **Default Go**: Homebrew Go at `/opt/homebrew/bin/go` (arm64)
- **Custom SDKs**: `~/go/sdk/go<version>/` (e.g., `~/go/sdk/go1.25.3`)
- **GOPATH**: `$HOME/go`
- **GOBIN**: `$HOME/go/bin` (added to PATH)

### Key Functions (in `scripts/common.sh`)

- **`go_use <version|default>`**: Switch Go toolchains
  - `go_use default` or `go_use homebrew` → use Homebrew Go
  - `go_use 1.25.3` → use `~/go/sdk/go1.25.3`
  - Automatically calls `show_go` to display active version and architecture

- **`go_list`**: List all installed Go toolchains with versions and architectures

- **`show_go <version> [--dir] <root>`**: Display current Go version and architecture

### Adding a New Go Version

```bash
cd ~/Downloads
curl -LO https://go.dev/dl/go1.X.Y.darwin-arm64.tar.gz
mkdir -p "$HOME/go/sdk"
tar -C "$HOME/go/sdk" -xzf go1.X.Y.darwin-arm64.tar.gz
mv "$HOME/go/sdk/go" "$HOME/go/sdk/go1.X.Y"
go_list  # Verify installation
```

## Binary Architecture Utilities

The repository includes utilities for managing the Intel→ARM migration on Apple Silicon:

### Key Functions (in `scripts/common.sh`)

- **`bin_arch <command>`**: Show architecture and type of a command-line binary
  - Resolves symlinks
  - Detects scripts vs binaries
  - Shows interpreter architecture for scripts

- **`app_arch <AppName|/path/to/App.app>`**: Show architecture of macOS applications

- **`audit_x86 [dirs...]`**: Scan directories for x86-only binaries

- **`reinstall_x86_casks [cask...]`**: Interactive tool to upgrade Homebrew casks from x86 to arm64

- **`reinstall_x86_bins [cmd...]`**: Interactive tool to migrate x86 Homebrew binaries to arm64
  - Maintains skip cache at `~/.init/cache/reinstall_x86_bins.skip`
  - Use `--clear-cache` to reset skip list

## Custom Binaries

### `bin/secret`

Retrieves secrets from `~/.init/.secrets.json`:

```bash
secret GORELEASER_KEY  # Returns value of .GORELEASER_KEY from JSON
```

Used in `zsh/zshenv` to set environment variables:
```bash
export GORELEASER_KEY="$(secret GORELEASER_KEY)"
```

### `bin/ssh` and `bin/scp`

Custom SSH wrappers (check implementation for specific behavior).

## Environment Variables

Set in `zsh/zshenv`:

- `INIT_DIR="${HOME}/.init"`
- `NVM_DIR="${HOME}/.nvm"`
- `GOPATH="${HOME}/go"`
- `GOBIN="${GOPATH}/bin"`
- `GOOGLE_CLOUD_PROJECT="stable-electron-464204-n4"`
- `GORELEASER_KEY` (loaded from `.secrets.json`)

PATH is constructed as:
```bash
export PATH="${GOBIN}:${HOME}/.init/bin:${PATH}"
```

## Common Aliases

Defined in `zsh/zshrc`:

- `glo='git log --oneline -20'`
- `wp-sync="rsync -avz --delete ./wordpress-root/ wp-deploy:/srv/wordpress/"`

## Working with This Repository

### Modifying Shell Configuration

Always edit files under `~/.init/`, NOT the top-level dotfiles:

- ✅ Edit `~/.init/zsh/zshrc`
- ❌ Edit `~/.zshrc`

### Testing Changes

After editing configuration:

```bash
source ~/.zshrc           # Reload interactive config
source ~/.zshenv          # Reload environment vars
# Or open a new terminal
```

### Adding New Shared Functions

1. Add function to `~/.init/scripts/common.sh`
2. Keep it POSIX-compatible (works in both Zsh and Bash)
3. Reload via `source ~/.zshrc`

### Setup Scripts

Scripts in `setup/` are **work in progress** and should be reviewed before running. They are not meant to be run automatically.

## Path Management

**CRITICAL**: The `~/.init/bin` directory is added to PATH in `zsh/zshrc` (line 49). This happens LAST to ensure custom binaries can override system binaries when needed.

Go-related binaries in `$GOBIN` are also on PATH (set in `zshenv` and reinforced in `zshrc`).

## Secrets Management

- Secrets are stored in `~/.init/.secrets.json` (gitignored)
- Access via `secret <key>` utility
- Format: Standard JSON with top-level keys

## Notes

- The repository is designed for macOS (specifically Apple Silicon, but maintains some Intel compatibility)
- Shell is Zsh (macOS default since Catalina)
- Some commented-out configuration exists in `zshrc` for future use
- The `init.yaml` file contains aliases but appears to be a different configuration format (possibly unused)