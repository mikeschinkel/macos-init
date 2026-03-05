# ADR 002: Shell & Dotfiles Architecture Using `~/.init` on macOS

- **Status:** Accepted
- **Date:** 2025-12-11
- **Applies to:** Personal macOS machines (currently M4 Mac mini daily driver)
- **Owner:** Mike Schinkel

## 1. Context

Historically, shell configuration (`.zshrc`, `.bashrc`, `.profile`, etc.) tends to accrete changes over time:

- Tools append directly to dotfiles (`echo 'eval ...' >> ~/.zprofile`).
- Experiments get baked in and forgotten.
- It becomes hard to reason about *what* runs *when* and *why*.

For this machine (and future ones), the goals are:

- Treat macOS shell configuration more like **Infrastructure as Code**:
  - Config is versioned and lives in a repo.
  - Rebuilding a Mac should be **declarative** and largely repeatable.
- Make the **top-level dotfiles** small, predictable, and boring.
- Centralize real logic in a single, inspectable directory.
- Allow sharing helpers between zsh and Bash (e.g., for Go helpers).

macOS now defaults to **zsh** as the login shell, but Bash 5 may later be installed via Homebrew for when Bash-specific behavior is desired.

## 2. Decision

Use a dedicated directory **`$HOME/.init`** as the **single source of truth** for shell configuration, and make the top-level dotfiles do nothing except **`source`** files from `~/.init`.

Specifically:

- All real zsh config lives under:

  - `~/.init/zsh/zshenv`
  - `~/.init/zsh/zprofile`
  - `~/.init/zsh/zshrc`

- Shared shell helpers live under:

  - `~/.init/scripts/` (e.g., `common.sh`)

- Top-level dotfiles are thin shims:

  ```sh
  # ~/.zshenv
  [ -r "$HOME/.init/zsh/zshenv" ] && . "$HOME/.init/zsh/zshenv"

  # ~/.zprofile
  [ -r "$HOME/.init/zsh/zprofile" ] && . "$HOME/.init/zsh/zprofile"

  # ~/.zshrc
  [ -r "$HOME/.init/zsh/zshrc" ] && . "$HOME/.init/zsh/zshrc"
  ```

- `~/.init/zsh/zshenv` is used for **global environment variables** and remains quiet (no output, no interactive behavior).
- `~/.init/zsh/zprofile` is used for **login-time setup**, such as Homebrew’s shellenv.
- `~/.init/zsh/zshrc` is used for **interactive configuration** only (prompt, aliases, fzf, etc.), and for sourcing shared helpers from `~/.init/scripts`.

## 3. Details

### 3.1 Directory structure

Intended structure:

```text
$HOME
├── .zshenv      # shim - forwards into ~/.init
├── .zprofile    # shim
├── .zshrc       # shim
└── .init
    ├── zsh
    │   ├── zshenv
    │   ├── zprofile
    │   └── zshrc
    ├── scripts
    │   └── common.sh
    └── Brewfile
```

The `.init` directory is where configuration is edited and version-controlled. The top-level dotfiles should almost never be touched once they point into `~/.init`.

### 3.2 `~/.init/zsh/zshenv`

Used for global, non-interactive-safe environment:

- No output.
- No reliance on being attached to a TTY.

Example responsibilities:

- Set `INIT_DIR`, `NVM_DIR`.
- Set Go workspace: `GOPATH`, `GOBIN`.
- Prepend `$GOBIN` to `PATH`.

```sh
# ~/.init/zsh/zshenv

export INIT_DIR="$HOME/.init"
export NVM_DIR="$HOME/.nvm"

export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$GOBIN:$PATH"
```

### 3.3 `~/.init/zsh/zprofile`

Used for **login shells** (once per login):

- Homebrew shellenv:

  ```sh
  # ~/.init/zsh/zprofile

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  ```

- Any other “once per login” initialization can go here (e.g., `PATH` tweaks that depend on Homebrew).

### 3.4 `~/.init/zsh/zshrc`

Used for **interactive** behavior only:

- `setopt`, `bindkey`, prompt configuration.
- Aliases.
- fzf / completion wiring.
- Loading shared helpers:

  ```sh
  if [ -r "$HOME/.init/scripts/common.sh" ]; then
    . "$HOME/.init/scripts/common.sh"
  fi
  ```

This separation keeps non-interactive scripts predictable and avoids polluting automated shells with interactive assumptions.

### 3.5 Shared helpers in `~/.init/scripts/`

`~/.init/scripts/common.sh` collects shell functions that are:

- Useful in both zsh and Bash.
- Core to the dev workflow (e.g., Go toolchain switching, binary arch inspection).

Examples:

- `go_use`, `go_list`, `show_go`
- `bin_arch`, `audit_x86`
- `app_arch`, `_cask_main_app_path`, `rearm_casks_x86` (conceptually)

Because `common.sh` avoids zsh-only features, it can be sourced from Bash 5 scripts when needed.

## 4. Alternatives Considered

1. **Keep everything in top-level dotfiles (`~/.zshrc`, etc.)**
   - Very common, but quickly becomes unstructured and hard to reason about.
   - Tools appending directly to dotfiles make history noisy and messy.
   - Harder to treat as “configuration as code.”

2. **Use a dotfile framework (e.g., Oh My Zsh, Prezto, etc.)**
   - Adds complexity and a lot of third-party behavior.
   - Less control over minimalism and exact behavior.
   - Not ideal for a highly customized dev-centric setup.

3. **Use symlinks from dotfiles to files in a Git repo**
   - Works, but still encourages the “everything in one file” pattern.
   - Harder to separate concerns between env/login/interactive.
   - Less obvious where shell helper scripts belong.

The chosen structure keeps things simple, explicit, and under personal control.

## 5. Consequences

### Positive

- **Single source of truth** for shell config under `~/.init`.
- Easy to **rebuild a new Mac** by copying `~/.init`, creating the three shim dotfiles, and running `brew bundle`.
- Dotfiles are **small and stable**; most changes happen in `~/.init`.
- Clear separation between:
  - Global env (`zshenv`)
  - Login-time setup (`zprofile`)
  - Interactive behavior (`zshrc`)
- Shared helpers are reusable between zsh and Bash 5.

### Negative / Tradeoffs

- Requires discipline: all changes must go into `~/.init`, not into `.zshrc` directly.
- Some tools still expect to append to `~/.zprofile` or `~/.zshrc`; their changes have to be manually integrated into `~/.init`.
- Slightly more moving parts when debugging early-login issues (must remember the shim → `.init` indirection).

## 6. Follow-Up

- Add a short `README.md` to `~/.init` documenting:
  - Where env vars live.
  - Where login-time vs interactive config lives.
  - How to add new shared helpers.
- Optionally add a simple install script that:
  - Writes or symlinks the three shim dotfiles if they’re missing.
  - Confirms `~/.init` structure is correct.
