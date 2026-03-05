# completion function paths (must be set before compinit)

if [ -d "$HOME/.docker/completions" ]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi

# Homebrew zsh completions (Apple Silicon default path)
if [ -d "/opt/homebrew/share/zsh/site-functions" ]; then
  fpath=("/opt/homebrew/share/zsh/site-functions" $fpath)
fi

# If you want your own completions:
if [ -d "$HOME/.init/zsh/completions" ]; then
  fpath=("$HOME/.init/zsh/completions" $fpath)
fi
