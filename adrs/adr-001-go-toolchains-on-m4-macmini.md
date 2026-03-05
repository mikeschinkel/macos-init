# ADR-001: Managing Multiple Go Toolchains on the M4 Mac mini

- **Status:** Accepted
- **Date:** 2025-12-11
- **Applies to:** Go development on macOS (M4 Mac mini and future Apple Silicon Macs)
- **Owner:** Mike Schinkel

## 1. Context

Go is a primary development language on this machine, and there are several requirements:

- Use the **latest stable Go** as the default for day-to-day work.
- Keep **multiple Go versions** around for:
  - Testing against specific versions.
  - Projects pinned to older Go releases.
- Make it **obvious which Go** is currently active on the CLI.
- Align **CLI Go toolchains** with **GoLand/JetBrains** configuration.
- Prefer **Apple Silicon (arm64)** toolchains, but allow older Intel (amd64) ones temporarily during migration.

On the M4:

- Native Go from Homebrew lives at `/opt/homebrew/bin/go` (arm64).
- Historical Go SDKs from the Intel mini are still present and some are `darwin/amd64`.

## 2. Decision

Adopt the following structure and behavior:

1. Use **Homebrew Go** at `/opt/homebrew/bin/go` as the **default** toolchain (`go_use default`).
2. Maintain additional Go SDKs under:

   ```text
   $HOME/go/sdk/go<version>/
   ```

   e.g.:

   ```text
   ~/go/sdk/go1.25.3
   ~/go/sdk/go1.25.5
   ```

3. Use a shared shell helper script (`~/.init/scripts/common.sh`) to define:

   - `go_use <version|default>` — switch active Go toolchain.
   - `go_list` — list all installed Go toolchains and their architectures.
   - `show_go` — print normalized information about the currently active Go.

4. Configure GoLand to use **the same toolchain directories** (`~/go/sdk/go<version>`) so IDE and CLI are aligned.

## 3. Details

### 3.1 Directory structure

Go workspace layout:

```text
$HOME/go
├── bin        # $GOBIN: go install -i writes here
├── pkg        # build cache / artifacts
└── sdk        # Go distributions
    ├── go1.25.3
    └── go1.25.5
```

Environment (from `~/.init/zsh/zshenv`):

```sh
export GOPATH="$HOME/go"
export GOBIN="$GOPATH/bin"
export PATH="$GOBIN:$PATH"
```

This ensures `go install`-installed binaries land in `~/go/bin` and are on `PATH`.

### 3.2 Default Go via Homebrew

Homebrew Go (arm64) is installed at:

```sh
which go
# /opt/homebrew/bin/go

go version
# go version go1.25.5 darwin/arm64
```

This toolchain is:

- Treated as the **“default”**.
- Selected via `go_use default`.
- Considered the baseline for new development, unless a project needs a specific version.

### 3.3 Pinned SDKs in `~/go/sdk`

Each pinned SDK is a full Go distribution unpacked from the official tarball and renamed:

- `go1.25.3` from `go1.25.3.darwin-<arch>.tar.gz`
- `go1.25.5` from `go1.25.5.darwin-<arch>.tar.gz`

Extraction flow (for a new version) is:

```sh
cd ~/Downloads
curl -LO https://go.dev/dl/go1.X.Y.darwin-arm64.tar.gz

mkdir -p "$HOME/go/sdk"
tar -C "$HOME/go/sdk" -xzf go1.X.Y.darwin-arm64.tar.gz
mv "$HOME/go/sdk/go" "$HOME/go/sdk/go1.X.Y"
```

### 3.4 `go_use` behavior

`go_use` (defined in `~/.init/scripts/common.sh`) accepts:

- `go_use default`
- `go_use 1.25.3`
- `go_use 1.25.5`
- etc.

Conceptual behavior:

- **`go_use default`**
  - Ensures `/opt/homebrew/bin` is early in `PATH` so `/opt/homebrew/bin/go` wins.
  - Leaves `GOROOT` unset (Go uses its compiled-in root).
  - Calls `show_go` to print something like:

    ```text
    Using Go default [darwin/arm64]
    ```

- **`go_use <version>`**
  - Computes the toolchain path: `$HOME/go/sdk/go<version>/bin/go`.
  - Verifies it exists and is executable.
  - Adjusts `PATH` so that this `bin` directory precedes other Go locations.
  - Optionally sets `GOROOT` to `$HOME/go/sdk/go<version>`.
  - Calls `show_go` to print:

    ```text
    Using Go 1.25.3 [darwin/amd64]
    ```

This makes the active Go version explicit, and avoids surprises when switching between projects or reproducing bugs on specific releases.

### 3.5 `go_list` behavior

`go_list` prints a summary of all toolchains:

```text
Default (Homebrew) Go:
  go version go1.25.5 darwin/arm64

Custom Go toolchains under /Users/mikeschinkel/go/sdk:
  1.25.5   go version go1.25.5 darwin/amd64
  1.25.3   go version go1.25.3 darwin/amd64
```

Implementation details (conceptually):

- Detect default Go via `/opt/homebrew/bin/go version`.
- Find all directories in `~/go/sdk` matching `go*`.
- Extract `<version>` from directory name.
- Run `<dir>/bin/go version` to show `darwin/arm64` vs `darwin/amd64`.
- Sort versions (currently descending).

This is the canonical view of “what Go versions exist?” and “which ones are still Intel-only?”

### 3.6 GoLand / JetBrains configuration

In GoLand:

- SDKs are configured to point at the same locations as CLI toolchains:
  - `~/go/sdk/go1.25.3`
  - `~/go/sdk/go1.25.5`
- Old SDK entries referencing `/usr/local/Cellar/go/...` are removed.
- For each project, the Go SDK chosen in GoLand should correspond to the version typically selected via `go_use` for that project.

This ensures:

- IDE and terminal use the same Go binaries.
- Reproducing behavior is straightforward, regardless of whether commands are run via GoLand or shell.

## 4. Alternatives Considered

1. **Use only Homebrew-managed Go versions**
   - Pros:
     - Simpler; `brew install go@1.X` and let Homebrew manage everything.
   - Cons:
     - Homebrew’s Go versioning and path semantics can be more complex.
     - Less control over naming and layout compared to a simple `~/go/sdk/go<version>` convention.
     - Ties Go installation too tightly to Homebrew conventions.

2. **Use `gvm`, `asdf`, or another version manager**
   - Pros:
     - Built-in version-switching semantics.
     - Often good for polyglot workflows.
   - Cons:
     - Additional layer of complexity.
     - Less transparent than direct directories and a small `go_use` wrapper.
     - Potential mismatch with GoLand’s expectations, depending on configuration.

3. **Rely on GoLand’s per-project SDKs and ignore the CLI**
   - Pros:
     - Only one system (GoLand) knows about toolchains.
   - Cons:
     - CLI workflows become “whatever happens to be in PATH.”
     - Harder to reproduce behavior outside the IDE.
     - Not suitable for heavy CLI-centric work.

The chosen approach gives a simple, explicit, and tool-agnostic layout that is easy to understand and script against.

## 5. Consequences

### Positive

- Clear separation between:
  - Default Go (Homebrew arm64).
  - Pinned SDKs (`~/go/sdk/go<version>`).
- Easy switching via `go_use`, with visible feedback via `show_go`.
- `go_list` provides a single authoritative inventory of toolchains and architectures.
- GoLand configuration matches CLI toolchains, reducing “works in IDE but not in shell” issues.
- Future migration from Intel-only SDKs to arm64 is straightforward: replace the directory contents and rerun `go_list`.

### Negative / Tradeoffs

- Requires manual download and unpacking when adding a new Go version (not a one-liner like `brew install go@x.y`).
- Slightly more logic in shell config (`go_use`, `go_list`), which must be maintained.
- If multiple shells are open, `go_use` is per-shell; changing versions in one shell does not propagate to others (which is expected, but worth noting).

## 6. Follow-Up

- Convert remaining `~/go/sdk/go<version>` directories from `darwin/amd64` to `darwin/arm64` by replacing them with official arm64 tarballs.
- Add lightweight tests (e.g., a script that runs `go_list` and validates expected versions) as a sanity check after major changes.
- Optionally extend `go_use` to:
  - Print a warning when selecting an Intel-only SDK on Apple Silicon.
  - Integrate with project directories (e.g., `go_use` based on configuration in the repo).
