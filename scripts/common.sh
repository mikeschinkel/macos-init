# Remember the original PATH before we start messing with Go toolchains
_go_init_base_path() {
    if [ -z "${_GO_PATH_BASE:-}" ]; then
        _GO_PATH_BASE="$PATH"
    fi
}

# Switch between Go versions:
#   go_use 1.25.3     -> ~/go/sdk/go1.25.3
#   go_use default    -> Homebrew Go (/opt/homebrew)
#   go_use homebrew   -> alias for default
go_use() {
    local ver="$1"
    local flag="$2"
    local root ver_str ver_display go_cmd

    _go_init_base_path

    case "$ver" in
        ""|"default"|"homebrew"|"system")
            # Prefer Apple Silicon brew go for "default"
            if [ -x /opt/homebrew/bin/go ]; then
                go_cmd=/opt/homebrew/bin/go
            else
                go_cmd=go
            fi

            # Ask that Go for GOROOT + version
            root="$($go_cmd env GOROOT 2>/dev/null)"
            ver_str="$($go_cmd version 2>/dev/null | awk '{print $3}')"   # e.g. go1.25.5
            ver_display="${ver_str#go}"                                  # -> 1.25.5

            [ -z "$root" ] && root="/opt/homebrew/opt/go/libexec"
            [ -z "$ver_display" ] && ver_display="default"

            show_go "$ver_display" "$flag" "$root"
            return 0
            ;;
    esac

    # Non-default: expect a version like "1.25.3" => ~/go/sdk/go1.25.3
    root="$HOME/go/sdk/go$ver"
    if [ ! -d "$root" ]; then
        echo "go_use: no such toolchain: $root" >&2
        return 1
    fi

    show_go "$ver" "$flag" "$root"
}

show_go() {
    local ver="$1"
    local flag="$2"
    local root="$3"

    export GOROOT="$root"
    export PATH="$GOROOT/bin:$_GO_PATH_BASE"

    # e.g. go version go1.25.5 darwin/arm64 -> darwin/arm64
    local arch
    arch="$(go version 2>/dev/null | awk '{print $4}')"

    printf '\nUsing Go %s [%s]\n\n' "$ver" "$arch"

    if [ "$flag" = "--dir" ]; then
        printf 'Dir: %s\n\n' "$GOROOT"
    fi
}

go_list() {
    echo "Default (Homebrew) Go:"
    if command -v /opt/homebrew/bin/go >/dev/null 2>&1; then
        local def_line def_ver
        def_line="$(/opt/homebrew/bin/go version 2>/dev/null)"   # e.g. "go version go1.25.5 darwin/arm64"
        def_ver="$(printf '%s\n' "$def_line" | awk '{print $3}')" # -> "go1.25.5"
        def_ver="${def_ver#go}"                                  # -> "1.25.5"
        printf '  %-8s %s\n' "$def_ver" "$def_line"
    else
        printf '  %-8s %s\n' "-" "(no Homebrew Go installed at /opt/homebrew/bin/go)"
    fi
    echo

    local sdk_root="$HOME/go/sdk"
    if [ ! -d "$sdk_root" ]; then
        echo "No custom Go toolchains found under $sdk_root"
        return 0
    fi

    echo "Custom Go toolchains under $sdk_root:"

    # Collect entries as "KEY|DIR" so we can sort them by KEY (version)
    local entries=()
    local dir ver major minor patch key

    for dir in "$sdk_root"/go*; do
        [ -d "$dir" ] || continue

        ver="${dir##*/}"   # e.g. 'go1.25.3'
        ver="${ver#go}"    # -> '1.25.3'

        # Split "1.25.3" into major/minor/patch
        major=0 minor=0 patch=0
        IFS='.' read -r major minor patch <<< "$ver"
        major="${major:-0}"
        minor="${minor:-0}"
        patch="${patch:-0}"

        # Build a sortable key, e.g. "001.025.003"
        key="$(printf '%03d.%03d.%03d' "$major" "$minor" "$patch")"

        entries+=("$key|$dir")
    done

    # Nothing found?
    if [ ${#entries[@]} -eq 0 ]; then
        echo "  (none found)"
        return 0
    fi

    # Sort by key descending
    local sorted=()
    IFS=$'\n' sorted=($(printf '%s\n' "${entries[@]}" | sort -r))
    unset IFS

    local entry go_bin
    for entry in "${sorted[@]}"; do
        key="${entry%%|*}"
        dir="${entry#*|}"
        ver="${dir##*/}"    # go1.25.3
        ver="${ver#go}"     # 1.25.3
        go_bin="$dir/bin/go"

        if [ -x "$go_bin" ]; then
            printf '  %-8s %s\n' "$ver" "$("$go_bin" version 2>/dev/null)"
        else
            printf '  %-8s (no go binary at %s)\n' "$ver" "$go_bin"
        fi
    done
}

_bin_arch_from_file_info() {
    # Given the output of `file -b`, return a simple arch string.
    # Examples:
    #   "Mach-O 64-bit executable arm64"           -> arm64
    #   "Mach-O 64-bit executable x86_64"          -> x86_64
    #   "Mach-O universal binary with ... arm64"   -> universal (arm64 + x86_64)
    local info="$1"
    local arch="unknown"

    case "$info" in
        *arm64*|*ARM64*)
            if printf '%s\n' "$info" | grep -q 'x86_64'; then
                arch="universal (arm64 + x86_64)"
            else
                arch="arm64"
            fi
            ;;
        *x86_64*)
            arch="x86_64"
            ;;
        *)
            arch="unknown"
            ;;
    esac

    printf '%s\n' "$arch"
}

_cask_main_app_path() {
    local cask="$1"

    brew list --cask --verbose "$cask" 2>/dev/null | awk '
        # Match any line containing ".app" followed by space, slash, ")", or end-of-line
        /\.app([[:space:]]|\/|\)|$)/ {
            line = $0

            # Strip any trailing " (App)"-style suffixes if they exist
            sub(/[[:space:]]+\(.*\)$/, "", line)

            # Trim everything after the .app so we get the bundle root
            sub(/\.app.*/, ".app", line)

            print line
            exit
        }
    '
}\

bin_arch() {
    if [ $# -eq 0 ]; then
        echo "Usage: bin_arch <command>" >&2
        return 1
    fi

    local cmd="$1"
    local bin_path
    local file_info first_line type arch="unknown"
    local link_target=""

    bin_path="$(command -v -- "$cmd" 2>/dev/null)" || {
        echo "bin_arch: '$cmd' not found in PATH" >&2
        echo "PATH is: $PATH" >&2
        return 1
    }

    # Resolve symlink target, if any
    if [ -L "$bin_path" ]; then
        link_target="$(readlink "$bin_path" 2>/dev/null || true)"
        # Normalize relative symlinks to absolute for readability
        case "$link_target" in
            /*) ;; # already absolute
            "" ) ;; # readlink failed
            * )
                link_target="$(cd "$(dirname "$bin_path")" && pwd)/$link_target"
                ;;
        esac
    fi

    # Base info about the file itself
    file_info="$(file -b "$bin_path" 2>/dev/null || echo "")"

    # Default type guess
    type="binary"

    # Look at shebang to detect scripts (node, python, shell, etc.)
    first_line="$(LC_ALL=C head -n 1 "$bin_path" 2>/dev/null || echo "")"
    case "$first_line" in
        "#!"*node*)
            type="node"
            if command -v node >/dev/null 2>&1; then
                arch="$(_bin_arch_from_file_info "$(file -b "$(command -v node)" 2>/dev/null)")"
            fi
            ;;
        "#!"*python*)
            type="python"
            local interp
            interp="$(printf '%s\n' "$first_line" | sed 's/^#![[:space:]]*//; s/[[:space:]].*$//')"
            if command -v "$interp" >/dev/null 2>&1; then
                arch="$(_bin_arch_from_file_info "$(file -b "$(command -v "$interp")" 2>/dev/null)")"
            fi
            ;;
        "#!"*bash*)
            type="bash script"
            if command -v bash >/dev/null 2>&1; then
                arch="$(_bin_arch_from_file_info "$(file -b "$(command -v bash)" 2>/dev/null)")"
            fi
            ;;
        "#!"*zsh*)
            type="zsh script"
            if command -v zsh >/dev/null 2>&1; then
                arch="$(_bin_arch_from_file_info "$(file -b "$(command -v zsh)" 2>/dev/null)")"
            fi
            ;;
        "#!"*sh*)
            type="sh script"
            if command -v sh >/dev/null 2>&1; then
                arch="$(_bin_arch_from_file_info "$(file -b "$(command -v sh)" 2>/dev/null)")"
            fi
            ;;
        "#!"*)
            type="script"
            ;;
        *)
            type="binary"
            ;;
    esac

    # If we still don't know arch, and it's a binary, infer from its own file info
    if [ "$type" = "binary" ] || [ "$arch" = "unknown" ]; then
        arch="$(_bin_arch_from_file_info "$file_info")"
    fi

    printf 'Arch: %s\n' "$arch"
    printf 'Type: %s\n' "$type"
    printf 'File: %s\n' "$bin_path"
    if [ -n "$link_target" ]; then
        printf 'Link: %s\n' "$link_target"
    fi
}
app_arch() {
    if [ $# -eq 0 ]; then
        echo "Usage: app_arch <AppName|/path/to/App.app>" >&2
        return 1
    fi

    local app="$1"

    # If it’s not an explicit .app path, assume /Applications/<name>.app
    case "$app" in
        *.app) ;;
        *)
            app="/Applications/$app.app"
            ;;
    esac

    if [ ! -d "$app" ]; then
        echo "app_arch: '$app' not found" >&2
        return 1
    fi

    local info_plist="$app/Contents/Info"
    local exe_name exe_path file_info arch

    # CFBundleExecutable tells us the main binary name
    exe_name="$(defaults read "$info_plist" CFBundleExecutable 2>/dev/null)" || {
        echo "app_arch: could not read CFBundleExecutable from $info_plist" >&2
        return 1
    }

    exe_path="$app/Contents/MacOS/$exe_name"

    if [ ! -x "$exe_path" ]; then
        echo "app_arch: executable '$exe_path' not found or not executable" >&2
        return 1
    fi

    file_info="$(file -b "$exe_path" 2>/dev/null || echo "")"
    arch="$(_bin_arch_from_file_info "$file_info")"

    printf 'Arch: %s\n' "$arch"
    printf 'App:  %s\n' "$app"
    printf 'Exec: %s\n' "$exe_path"
}

audit_x86() {
    # Usage:
    #   audit_x86                  # scan default dirs
    #   audit_x86 /dir1 /dir2 ...  # scan specific dirs

    local scan_dirs=()
    if [ "$#" -gt 0 ]; then
        scan_dirs=("$@")
    else
        scan_dirs=(/usr/local/bin /opt/homebrew/bin "$HOME/bin")
    fi

    local d f info target

    for d in "${scan_dirs[@]}"; do
        [ -d "$d" ] || continue

        for f in "$d"/*; do
            [ -f "$f" ] || continue
            [ -x "$f" ] || continue

            info="$(file -b "$f" 2>/dev/null || echo "")"

            case "$info" in
                *x86_64*)
                    # Skip universal binaries (contain both x86_64 and arm64)
                    case "$info" in
                        *arm64*|*ARM64*)
                            ;;
                        *)
                            if [ -L "$f" ]; then
                                target="$(readlink "$f" 2>/dev/null || true)"
                                case "$target" in
                                    /*) ;;                          # already absolute
                                    "" ) ;;                         # unresolved
                                    * )
                                        target="$(cd "$(dirname "$f")" && pwd)/$target"
                                        ;;
                                esac
                                if [ -n "$target" ]; then
                                    printf '%s -> %s\n' "$f" "$target"
                                else
                                    printf '%s\n' "$f"
                                fi
                            else
                                printf '%s\n' "$f"
                            fi
                            ;;
                    esac
                    ;;
            esac
        done
    done
}

intel_bin_plan() {
    # Usage:
    #   intel_bin_plan
    #   intel_bin_plan > ~/intel-cli-bins-$(date +%Y%m%d-%H%M%S).csv
    #
    # CSV columns:
    #   bin_path,link_target,formula,arch_desc

    local f info link_target formula tmp

    echo "bin_path,link_target,formula,arch_desc"

    for f in /usr/local/bin/*; do
        [ -f "$f" ] || continue
        [ -x "$f" ] || continue

        info="$(file -b "$f" 2>/dev/null || echo "")"

        case "$info" in
            *"Mach-O"*)
                case "$info" in
                    *"x86_64"*)
                        case "$info" in
                            *"arm64"*)
                                # universal, skip
                                continue
                                ;;
                            *)
                                # pure x86_64, keep
                                ;;
                        esac
                        ;;
                    *)
                        continue
                        ;;
                esac
                ;;
            *)
                continue
                ;;
        esac

        link_target=""
        if [ -L "$f" ]; then
            link_target="$(readlink "$f" 2>/dev/null || true)"
            case "$link_target" in
                /*) ;; # already absolute
                "")
                    ;;
                *)
                    # normalize relative symlink to absolute for easier reading
                    link_target="$(cd "$(dirname "$f")" && pwd)/$link_target"
                    ;;
            esac
        fi

        formula=""
        if [ -n "$link_target" ]; then
            case "$link_target" in
                *"Cellar/"*"/bin/"*)
                    tmp=${link_target#*Cellar/}
                    formula=${tmp%%/*}
                    ;;
            esac
        fi

        printf '%s,%s,%s,"%s"\n' \
            "$f" \
            "$link_target" \
            "$formula" \
            "$info"
    done
}

intel_cask_plan() {
    # Usage:
    #   intel_cask_plan
    #   intel_cask_plan > ~/intel-casks-$(date +%Y%m%d-%H%M%S).csv
    #
    # CSV columns:
    #   cask,arch,app_path,exec_path

    local BREW_ARM="/opt/homebrew/bin/brew"
    local cask app_path info_plist exec_name exec_path file_info arch

    if [ ! -x "$BREW_ARM" ]; then
        echo "intel_cask_plan: $BREW_ARM not found or not executable" >&2
        return 1
    fi

    echo "cask,arch,app_path,exec_path"

    while IFS= read -r cask; do
        app_path="$(_cask_main_app_path "$cask")"
        if [ -z "$app_path" ]; then
            continue
        fi

        info_plist="$app_path/Contents/Info.plist"
        if [ ! -f "$info_plist" ]; then
            continue
        fi

        exec_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_plist" 2>/dev/null || true)
        if [ -z "$exec_name" ]; then
            continue
        fi

        exec_path="$app_path/Contents/MacOS/$exec_name"
        if [ ! -f "$exec_path" ]; then
            continue
        fi

        file_info="$(file -b "$exec_path" 2>/dev/null || echo "")"
        arch="$(_bin_arch_from_file_info "$file_info")"

        printf '%s,%s,%s,%s\n' \
            "$cask" \
            "$arch" \
            "$app_path" \
            "$exec_path"
    done < <("$BREW_ARM" list --cask --quiet)
}

reinstall_x86_casks() {
    # Usage:
    #   reinstall_x86_casks
    #       -> scan ALL Homebrew casks, prompt per x86-only app
    #
    #   reinstall_x86_casks Soulver
    #       -> if Soulver is a cask, show arch + optionally reinstall
    #       -> if Soulver is NOT a cask, show app_arch + explanation
    #
    #   reinstall_x86_casks cask1 cask2 ...
    #       -> limit to these casks (ignore non-installed names)

    local arg_count="$#"
    local mode_all=0
    local found_x86=0
    local cask app_path arch_before arch_after answer name

    # Handle Ctrl-C nicely
    trap 'printf "\nAborted by Ctrl-C\n"; trap - INT; return 130' INT

    if [ "$arg_count" -gt 0 ]; then
        # Explicit names
        for name in "$@"; do
            if ! brew list --cask --versions "$name" >/dev/null 2>&1; then
                if [ "$arg_count" -eq 1 ]; then
                    printf "reinstall_x86_casks: '%s' is not an installed Homebrew cask.\n" "$name"
                    app_arch "$name" || true
                    echo "reinstall_x86_casks: no automated upgrade available from this function."
                else
                    printf "reinstall_x86_casks: '%s' is not an installed Homebrew cask; skipping\n" "$name"
                fi
                continue
            fi

            cask="$name"
            app_path="$(_cask_main_app_path "$cask")"
            if [ -z "$app_path" ]; then
                continue
            fi

            arch_before="$(
                app_arch "$app_path" 2>/dev/null | awk '/^Arch:/ {print $2}'
            )"
            if [ -z "$arch_before" ]; then
                printf "[%s] Could not determine arch for %s, skipping\n" "$cask" "$app_path"
                continue
            fi

            printf '\nCask: %s\n' "$cask"
            printf '  App:  %s\n' "$app_path"
            printf '  Arch: %s\n' "$arch_before"

            if [ "$arch_before" != "x86_64" ]; then
                echo "  (No action: main binary is not pure x86_64.)"
                continue
            fi

            found_x86=1

            if [ "$mode_all" -eq 0 ]; then
                printf 'Action? [y]es/[n]o/[a]ll/[q]uit (default: y) > '
                IFS= read -r answer </dev/tty

                case "$answer" in
                    ""|"y"|"Y")
                        ;;
                    "n"|"N")
                        printf '  Skipping %s\n' "$cask"
                        continue
                        ;;
                    "a"|"A")
                        mode_all=1
                        printf '  Will re-arm this and all remaining x86-only casks.\n'
                        ;;
                    "q"|"Q")
                        printf 'Quitting.\n'
                        trap - INT
                        return 0
                        ;;
                    *)
                        printf '  Unrecognized answer "%s", treating as "n".\n' "$answer"
                        continue
                        ;;
                esac
            else
                printf "  (auto mode: reinstalling without prompt)\n"
            fi

            printf '  Reinstalling %s...\n' "$cask"

            if ! brew uninstall --cask "$cask"; then
                printf '  WARNING: uninstall failed for %s\n' "$cask"
                continue
            fi

            if ! brew install --cask "$cask"; then
                printf '  WARNING: install failed for %s\n' "$cask"
                continue
            fi

            app_path="$(_cask_main_app_path "$cask")"
            if [ -n "$app_path" ]; then
                arch_after="$(
                    app_arch "$app_path" 2>/dev/null | awk '/^Arch:/ {print $2}'
                )"
                printf '  Arch after: %s\n' "$arch_after"
            else
                printf '  Reinstalled but could not find app bundle afterwards.\n'
            fi
        done
    else
        # No args: scan all casks from brew, one per iteration.
        while IFS= read -r cask; do
            app_path="$(_cask_main_app_path "$cask")"
            if [ -z "$app_path" ]; then
                continue
            fi

            arch_before="$(
                app_arch "$app_path" 2>/dev/null | awk '/^Arch:/ {print $2}'
            )"
            if [ -z "$arch_before" ]; then
                printf "[%s] Could not determine arch for %s, skipping\n" "$cask" "$app_path"
                continue
            fi

            # Only care about pure x86_64 in the bulk scan
            if [ "$arch_before" != "x86_64" ]; then
                continue
            fi

            printf '\nCask: %s\n' "$cask"
            printf '  App:  %s\n' "$app_path"
            printf '  Arch: %s\n' "$arch_before"

            found_x86=1

            if [ "$mode_all" -eq 0 ]; then
                printf 'Reinstall this x86-only cask now? [y]es/[n]o/[a]ll/[q]uit (default: y) > '
                IFS= read -r answer </dev/tty

                case "$answer" in
                    ""|"y"|"Y")
                        ;;
                    "n"|"N")
                        printf '  Skipping %s\n' "$cask"
                        continue
                        ;;
                    "a"|"A")
                        mode_all=1
                        printf '  Will re-arm this and all remaining x86-only casks.\n'
                        ;;
                    "q"|"Q")
                        printf 'Quitting.\n'
                        trap - INT
                        return 0
                        ;;
                    *)
                        printf '  Unrecognized answer "%s", treating as "n".\n' "$answer"
                        continue
                        ;;
                esac
            else
                printf "  (auto mode: reinstalling without prompt)\n"
            fi

            printf '  Reinstalling %s...\n' "$cask"

            if ! brew uninstall --cask "$cask"; then
                printf '  WARNING: uninstall failed for %s\n' "$cask"
                continue
            fi

            if ! brew install --cask "$cask"; then
                printf '  WARNING: install failed for %s\n' "$cask"
                continue
            fi

            app_path="$(_cask_main_app_path "$cask")"
            if [ -n "$app_path" ]; then
                arch_after="$(
                    app_arch "$app_path" 2>/dev/null | awk '/^Arch:/ {print $2}'
                )"
                printf '  Arch after: %s\n' "$arch_after"
            else
                printf '  Reinstalled but could not find app bundle afterwards.\n'
            fi
        done < <(brew list --cask --quiet)
    fi

    trap - INT

    if [ "$found_x86" -eq 0 ] && [ "$arg_count" -eq 0 ]; then
        echo "reinstall_x86_casks: no x86-only Homebrew casks found."
    fi
}

reinstall_x86_bins() {
    # Usage:
    #   reinstall_x86_bins
    #       -> scan /usr/local/bin for x86-only Mach-O binaries that look like Homebrew Cellar links
    #
    #   reinstall_x86_bins cmd1 cmd2 ...
    #       -> limit to specific commands (resolved via command -v or treated as explicit paths)
    #
    # For each candidate that maps to a Homebrew formula, this can:
    #   - Install an arm64/universal version via /opt/homebrew/bin/brew (IF not already installed)
    #   - Optionally delete the /usr/local/bin shim
    #   - Optionally delete the Intel Cellar tree (/usr/local/Cellar/<formula>)
    #
    # It also maintains a skip list at:
    #   ~/.init/cache/reinstall_x86_bins.skip
    # Any bin path recorded there will be ignored on future bulk runs (no-arg).
    #
    # Requires: _bin_arch_from_file_info to be defined (same helper used by bin_arch/app_arch).
    #
    local BREW_ARM="/opt/homebrew/bin/brew"

    if [ ! -x "$BREW_ARM" ]; then
        echo "reinstall_x86_bins: $BREW_ARM not found or not executable" >&2
        return 1
    fi

    local CACHE_DIR="$HOME/.init/cache"
    local SKIP_FILE="$CACHE_DIR/reinstall_x86_bins.skip"

    # Ensure cache dir exists
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR" 2>/dev/null || true
    fi

    # Optional: reset skip cache
    if [ "$1" = "--clear-cache" ]; then
        if [ -f "$SKIP_FILE" ]; then
            rm -f "$SKIP_FILE" && echo "reinstall_x86_bins: cleared skip cache $SKIP_FILE"
        else
            echo "reinstall_x86_bins: no skip cache to clear ($SKIP_FILE)"
        fi
        return 0
    fi

    local mode_all_install=0

    # Helper: mark a bin path as skipped (if not already present)
    _reinstall_x86_bins_mark_skip() {
        local p="$1"
        if [ -z "$p" ]; then
            return 0
        fi
        if [ -f "$SKIP_FILE" ] && grep -Fqx "$p" "$SKIP_FILE" 2>/dev/null; then
            return 0
        fi
        printf '%s\n' "$p" >>"$SKIP_FILE"
    }

    _reinstall_x86_bins_handle_one() {
        # $1 = bin_path
        # $2 = explicit_flag (1 if called via explicit args, 0 if via bulk scan)
        local bin_path="$1"
        local explicit_flag="$2"

        # Only regular executable files
        [ -f "$bin_path" ] || return 0
        [ -x "$bin_path" ] || return 0

        # In bulk mode (no-arg run), honor skip list
        if [ "$explicit_flag" -eq 0 ] && [ -f "$SKIP_FILE" ]; then
            if grep -Fqx "$bin_path" "$SKIP_FILE" 2>/dev/null; then
                return 0
            fi
        fi

        local c_info c_arch link_target formula tmp
        local answer new_path new_info new_arch installed_ok=0
        local arm_installed=0

        c_info="$(file -b "$bin_path" 2>/dev/null || echo "")"
        c_arch="$(_bin_arch_from_file_info "$c_info")"

        # Resolve symlink if present
        link_target=""
        if [ -L "$bin_path" ]; then
            link_target="$(readlink "$bin_path" 2>/dev/null || true)"
            case "$link_target" in
                /*) ;; # already absolute
                "" ) ;; # unresolved
                * )
                    link_target="$(cd "$(dirname "$bin_path")" && pwd)/$link_target"
                    ;;
            esac
        fi

        # Try to extract a formula name if it's a Cellar path
        formula=""
        if [ -n "$link_target" ]; then
            case "$link_target" in
                *"/Cellar/"*"/bin/"*)
                    tmp=${link_target#*/Cellar/}
                    formula=${tmp%%/*}
                    ;;
            esac
        fi

        echo
        echo "Name:    $(basename "$bin_path")"
        echo "Path:    $bin_path"
        [ -n "$link_target" ] && echo "Link:    $link_target"
        echo "Arch:    $c_arch"
        [ -n "$formula" ] && echo "Formula: $formula"

        # If not x86-only, report and bail (and mark as seen to avoid repeated noise)
        if [ "$c_arch" != "x86_64" ]; then
            case "$c_info" in
                *script*|*Script*)
                    echo "Note:    this appears to be a script (architecture-agnostic); nothing to do."
                    _reinstall_x86_bins_mark_skip "$bin_path"
                    ;;
                *)
                    if [ -z "$c_arch" ] || [ "$c_arch" = "unknown" ]; then
                        echo "Note:    architecture could not be determined; leaving unchanged."
                        _reinstall_x86_bins_mark_skip "$bin_path"
                    else
                        echo "Note:    already $c_arch; nothing to do."
                        _reinstall_x86_bins_mark_skip "$bin_path"
                    fi
                    ;;
            esac
            return 0
        fi


        # If we can't map to a formula, this is manual-migration territory
        if [ -z "$formula" ]; then
            echo "Note:    x86-only and not a Homebrew Cellar binary; manual migration needed."
            _reinstall_x86_bins_mark_skip "$bin_path"
            return 0
        fi

        # Check if arm64/universal formula is already installed in /opt/homebrew
        if "$BREW_ARM" list --versions "$formula" >/dev/null 2>&1; then
            arm_installed=1
        fi

        # If not installed, offer to install arm64/universal via /opt/homebrew
        if [ "$arm_installed" -eq 0 ]; then
            if [ "$mode_all_install" -eq 0 ]; then
                printf 'Install arm64/universal via %s now?\n' "$BREW_ARM"
                printf 'This will run `%s install %s`.\n' "$BREW_ARM" "$formula"
                printf '[y]es/[n]o/[a]ll/[q]uit (default: y) > '
                IFS= read -r answer </dev/tty

                case "$answer" in
                    ""|"y"|"Y")
                        ;;
                    "n"|"N")
                        echo "  Skipping install for $formula"
                        _reinstall_x86_bins_mark_skip "$bin_path"
                        return 0
                        ;;
                    "a"|"A")
                        mode_all_install=1
                        echo "  Will install arm64/universal for this and all remaining candidates without further prompts."
                        ;;
                    "q"|"Q")
                        echo "Quitting."
                        return 130
                        ;;
                    *)
                        echo "  Unrecognized answer \"$answer\", treating as \"n\"."
                        _reinstall_x86_bins_mark_skip "$bin_path"
                        return 0
                        ;;
                esac
            else
                printf "  (auto mode: installing via %s)\n" "$BREW_ARM"
            fi

            if ! "$BREW_ARM" install "$formula"; then
                echo "  WARNING: install failed for $formula; checking PATH anyway."
            fi
        else
            echo "Note:    arm64/universal formula '$formula' already installed via $BREW_ARM; skipping install."
        fi

        # Show what the name now resolves to, if on PATH
        if command -v "$(basename "$bin_path")" >/dev/null 2>&1; then
            new_path="$(command -v "$(basename "$bin_path")")"
            new_info="$(file -b "$new_path" 2>/dev/null || echo "")"
            new_arch="$(_bin_arch_from_file_info "$new_info")"
            echo "  New resolved binary: $new_path"
            echo "  New arch:            $new_arch"

            case "$new_path" in
                /usr/local/*)
                    # Still resolving to Intel tree; do NOT consider this safe for deletion.
                    installed_ok=0
                    ;;
                *)
                    # Non-/usr/local path AND non-x86-only arch => safe to treat as replacement.
                    if [ -n "$new_arch" ] && [ "$new_arch" != "x86_64" ]; then
                        installed_ok=1
                    fi
                    ;;
            esac
        else
            echo "  WARNING: command $(basename "$bin_path") is not on PATH after install; leaving Intel copy alone."
            installed_ok=0
        fi

        if [ "$installed_ok" -eq 0 ]; then
            if [ "$arm_installed" -eq 1 ]; then
                # Formula exists in /opt/homebrew, but this specific helper has no non-Intel twin.
                echo "  Note: formula '$formula' is installed via $BREW_ARM, but command '$(basename "$bin_path")'"
                echo "        still resolves to $bin_path ($c_arch); keeping Intel shim/Cellar and marking for manual migration."
            else
                # No arm64 formula + no non-Intel replacement on PATH.
                echo "  Note: no confirmed non-Intel replacement on PATH; keeping Intel shim/Cellar and marking for manual migration."
            fi
            _reinstall_x86_bins_mark_skip "$bin_path"
            return 0
        fi


        # Now optionally clean up Intel shim and Cellar tree
        # Remove /usr/local/bin shim if it's under /usr/local/bin
        if [ "${bin_path%/*}" = "/usr/local/bin" ]; then
            echo "  Upshot:"
            printf "    1. Command '%s' now resolves to %s (%s).\n" \
                "$(basename "$bin_path")" "$new_path" "$new_arch"
            if [ -n "$link_target" ]; then
                link_target="$(cd "$(dirname "$link_target")" && pwd)/$(basename "$link_target")"
                printf "    2. %s is now a legacy Intel shim.\n" "$bin_path"
                printf "    3. Legacy shim points to %s.\n" "$link_target"
            else
                printf "    2. %s is now a legacy Intel shim.\n" \
                    "$bin_path"
            fi

            printf '  Delete Intel shim? [y/N] > '
            IFS= read -r answer </dev/tty
            case "$answer" in
                "y"|"Y")
                    rm -f -- "$bin_path" && echo "  Removed $bin_path"
                    ;;
                *)
                    echo "  Leaving shim in place."
                    ;;
            esac
        fi

        # Remove Intel Cellar tree if we know it
        if [ -n "$formula" ] && [ -n "$link_target" ]; then
            # link_target like /usr/local/Cellar/sqlc/1.29.0/bin/sqlc
            # formula_dir -> /usr/local/Cellar/sqlc
            local formula_dir
            formula_dir="$(printf '%s\n' "$link_target" | sed 's|\(/Cellar/[^/]*\)/.*|\1|')"
            if [ -n "$formula_dir" ] && [ -d "$formula_dir" ]; then
                printf '  Delete Intel Cellar tree %s ? [y/N] > ' "$formula_dir"
                IFS= read -r answer </dev/tty
                case "$answer" in
                    "y"|"Y")
                        rm -rf -- "$formula_dir" && echo "  Removed $formula_dir"
                        ;;
                    *)
                        echo "  Leaving Intel Cellar tree in place."
                        ;;
                esac
            fi
        fi

        return 0
    }

    if [ "$#" -gt 0 ]; then
        # Explicit commands/paths
        local name bin_path
        for name in "$@"; do
            if [ -x "$name" ]; then
                _reinstall_x86_bins_handle_one "$name" 1
                continue
            fi

            bin_path="$(command -v -- "$name" 2>/dev/null || true)"
            if [ -z "$bin_path" ]; then
                echo "reinstall_x86_bins: '$name' not found in PATH; skipping" >&2
                continue
            fi

            _reinstall_x86_bins_handle_one "$bin_path" 1
        done
    else
        # Default: scan /usr/local/bin only; that's where Intel Homebrew shims live.
        local d="/usr/local/bin" bin_path
        if [ -d "$d" ]; then
            for bin_path in "$d"/*; do
                _reinstall_x86_bins_handle_one "$bin_path" 0
            done
        fi
    fi

    return 0
}


