#!/usr/bin/env zsh -i
# shellcheck disable=SC2096

# Install/update Node.js LTS
nvm install --lts
nvm alias default lts/*

# Display Node.js and npm versions
echo "Node.js version: $(node -v)"
echo "npm version: $(npm -v)"

# Install/update pnpm
npm install -g pnpm

# Create ~/bin directory if it doesn't exist
mkdir -p ~/bin

# Find the actual pnpm executable path
PNPM_PATH=$(which pnpm 2>/dev/null || echo "$(npm config get prefix)/bin/pnpm")

# Create symlink in ~/bin (will overwrite if exists)
ln -sf "$PNPM_PATH" ~/bin/pnpm
echo "Created pnpm symlink in ~/bin"

# Display pnpm version (using the symlink if ~/bin is in PATH)
if [[ -x ~/bin/pnpm ]]; then
  echo "pnpm version: $(~/bin/pnpm --version)"
else
  echo "pnpm version: $(pnpm --version)"
fi

echo "Setup complete!"