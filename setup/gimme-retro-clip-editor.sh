#!/usr/bin/env bash
// SEE: https://chatgpt.com/share/694abcee-bdb4-800a-a007-89eebe18fd33

set -euo pipefail

# fix-retroclip-editor.sh
# Re-register RetroClip’s bundled “RetroClip Editor.app” with LaunchServices
# so it reappears in Finder → Open With.

EDITOR_APP="/Applications/RetroClip.app/Contents/Helpers/RetroClip Editor.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ ! -d "$EDITOR_APP" ]]; then
  echo "ERROR: RetroClip Editor not found at:"
  echo "  $EDITOR_APP"
  echo
  echo "Is RetroClip installed in /Applications as RetroClip.app?"
  exit 1
fi

if [[ ! -x "$LSREGISTER" ]]; then
  echo "ERROR: lsregister not found/executable at:"
  echo "  $LSREGISTER"
  exit 1
fi

echo "Registering:"
echo "  $EDITOR_APP"
"$LSREGISTER" -f "$EDITOR_APP"

echo "Restarting Finder..."
killall Finder >/dev/null 2>&1 || true

echo "Done. 'RetroClip Editor' should now appear under Finder → Open With."
