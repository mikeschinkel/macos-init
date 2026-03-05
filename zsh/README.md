# Zsh Initialization Files

1. **`.zshenv`**:
    - Always sourced, for every Zsh instance (login, interactive, scripts)
    - Should contain essential environment variables needed by all shell instances
    - Keep this file lean as it affects performance of every shell operation

2. **`.zprofile`**:
    - Sourced for login shells
    - Similar role to `.bash_profile` in Bash
    - Used for commands that should run only once at login

3. **`.zshrc`**:
    - Sourced for interactive shells only
    - The main configuration file for interactive Zsh use
    - Contains aliases, functions, options, prompt configuration, and plugin loading
    - This is where most of your customization will go

4. **`.zlogin`**:
    - Sourced at the end of login shell startup
    - Used for commands that should run after `.zshrc` is processed
    - Less commonly used than `.zshrc`

5. **`.zlogout`**:
    - Sourced when login shells exit
    - Similar to `.bash_logout`

# Load Order for Zsh

For login shells, the order is:
1. `.zshenv`
2. `.zprofile`
3. `.zshrc`
4. `.zlogin`

When logging out:
5. `.zlogout`

# Best Practices

- **Environment Variables**: Define in `.zshenv` 
- **PATH Modifications**: Define in `.zshenv` or `.zprofile` 
- **Aliases and Functions**: Define in `.zshrc` 
- **Interactive Settings**: Put in `.zshrc` 
- **Prompts**: Configure in `.zshrc` 
- **One-time Login Tasks**: Put in `.zprofile` 

# macOS Specifics

On macOS, Terminal.app opens login shells by default, which is different from most Linux systems. This means your `.bash_profile` or `.zprofile` and `.zshrc` will be read when you open a new terminal window.

Since macOS Catalina (10.15), Zsh is the default shell instead of Bash, so focusing on the Zsh configuration files makes sense for your new setup.

---

## Local Zsh Configuration Layout (`~/.init/zsh`)

While Zsh has multiple initialization files, this system centralizes all
interactive configuration under `~/.init/zsh`.

The user’s `~/.zshrc` contains only:

```sh
[ -r "$HOME/.init/zsh/zshrc" ] && source "$HOME/.init/zsh/zshrc"
````

### Directory Structure

* `zshrc`
  Entry point for interactive shells.
  Sources all files in `rc.d/` in numeric order.

* `rc.d/`
  Modular configuration files.
  Ordering is intentional.

   * `20-completion-paths.zsh`
     Adds Zsh completion function directories to `$fpath`.
     Includes Docker Desktop completions from `~/.docker/completions`.

   * `90-compinit.zsh`
     Initializes the Zsh completion system via `compinit`.
     This file is the *only* place where `compinit` is called.

### Design Goals

* Full ownership of shell configuration
* No vendor tools modifying `~/.zshrc`
* Predictable startup ordering
* Clear separation between configuration and documentation

- Add:
```

~/.init/zsh/ARCHITECTURE.md

```
for deeper rationale (Docker, Homebrew, compinit rules, etc.)

But that’s optional. What’s above is already a solid, maintainable solution.

If you want, I can:
- Rewrite the full README with the new section merged cleanly
- Or help you document *other* rc.d modules as they grow

Just say which.
```
