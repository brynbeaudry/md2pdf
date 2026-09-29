#!/usr/bin/env bash
# install.sh — copy md2pdf to a PATH directory and report missing dependencies.
# Usage:  ./install.sh [dest_dir]   (default: ~/.local/bin)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/.local/bin}"

mkdir -p "$DEST"
cp -f "$HERE/md2pdf" "$DEST/md2pdf"
chmod +x "$DEST/md2pdf"
echo "✓ installed $DEST/md2pdf"

case ":$PATH:" in
  *":$DEST:"*) echo "✓ $DEST already on PATH";;
  *)
    echo "⚠ $DEST is not on PATH. Add it with one of:"
    echo "    echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    echo "    echo 'export PATH=\"$DEST:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    ;;
esac

missing=0
check() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "⚠ missing: $1 — install with: $2"
    missing=1
  else
    echo "✓ found: $1"
  fi
}
check node      "brew install node   (or https://nodejs.org)"
check npm       "comes with node — see above"
check md-to-pdf "npm install -g md-to-pdf"
check mmdc      "npm install -g @mermaid-js/mermaid-cli"
check curl      "(should be preinstalled; otherwise your OS package manager)"

if [[ $missing -eq 0 ]]; then
  echo "All set. Try:  md2pdf -h"
else
  echo "Install the missing tools above, then run:  md2pdf -h"
fi
