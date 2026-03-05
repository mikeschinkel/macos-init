# Zsh Configuration Architecture

This document explains the design constraints and invariants of the Zsh
configuration under `~/.init/zsh`. It exists to prevent configuration drift
and accidental breakage over time.

## 1. Ownership Model

All interactive Zsh configuration is owned by `~/.init/zsh`.

The user’s `~/.zshrc` contains only a delegation to this directory. No
third-party tools are allowed to modify `~/.zshrc` directly.

Vendor-supplied configuration (e.g. Docker Desktop) must be relocated into
explicit, owned modules under `rc.d/`.

## 2. Entry Points

- `~/.zshrc` → delegates to `~/.init/zsh/zshrc`
- `~/.init/zsh/zshrc` → sources `rc.d/*.zsh` in numeric order

No other files may source `rc.d` directly.

## 3. Module Ordering Rules

Modules in `rc.d/` are ordered numerically.

Key invariants:

- Files that modify `fpath` must run **before** `compinit`
- `compinit` must be called **exactly once**
- `PATH` modifications must occur after all toolchains are defined

Violating these rules may result in broken completions or unpredictable shell
startup behavior.

## 4. Completion System Design

The Zsh completion system is initialized in exactly one file:

- `rc.d/90-compinit.zsh`

All completion function paths (Docker, Homebrew, custom) must be added via
`fpath` **before** this file executes.

The completion dump file is stored under:

```

~/.cache/zsh/zcompdump-<zsh-version>

```

This avoids polluting `$HOME` and ensures version-safe caching.

## 5. External Tool Integration

### Docker Desktop

Docker Desktop installs Zsh completion functions under:

```

~/.docker/completions

```

Rather than allowing Docker to inject configuration into `~/.zshrc`, this
directory is conditionally added to `fpath` in:

- `rc.d/20-completion-paths.zsh`

### Homebrew

Homebrew-provided completions are sourced from:

```

/opt/homebrew/share/zsh/site-functions

```

No Homebrew scripts are allowed to call `compinit`.

## 6. Extension Guidelines

When adding new configuration:

- Prefer adding a new `rc.d/NN-description.zsh` file
- Do not call `compinit`
- Do not assume execution order beyond numeric ordering
- Keep modules single-purpose
- Document *why* a module exists in README or here, not inline prose

If a change requires breaking an invariant, update this document first.


