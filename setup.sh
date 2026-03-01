#!/bin/bash
# setup.sh - Link vimrc and set up competitive programming environment
# Usage: ./setup.sh [--force]

set -euo pipefail

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIMRC_SOURCE="$SCRIPT_DIR/vimrc"
HOME_VIMRC="$HOME/.vimrc"
HOME_VIM="$HOME/.vim"

echo "=== CP Template Setup ==="

# Check if vimrc exists
if [[ ! -f "$VIMRC_SOURCE" ]]; then
    echo "ERROR: vimrc not found at $VIMRC_SOURCE"
    exit 1
fi

# Backup existing .vimrc if it exists and not a symlink
if [[ -f "$HOME_VIMRC" && ! -L "$HOME_VIMRC" ]]; then
    if [[ "$FORCE" == "true" ]]; then
        cp "$HOME_VIMRC" "$HOME_VIMRC.backup.$(date +%Y%m%d)"
        echo "Backed up existing .vimrc"
    else
        echo "WARNING: .vimrc already exists. Use --force to overwrite"
        echo "Skipping vimrc setup"
    fi
fi

# Create symlink to vimrc
if [[ "$FORCE" == "true" || ! -f "$HOME_VIMRC" ]]; then
    ln -sf "$VIMRC_SOURCE" "$HOME_VIMRC"
    echo "Linked vimrc to $HOME_VIMRC"
fi

# Create vim directories
mkdir -p "$HOME_VIM/undodir"
mkdir -p "$HOME_VIM/templates"
echo "Created vim directories"

# Copy template file
if [[ -f "$SCRIPT_DIR/templates/cpp.template" ]]; then
    cp "$SCRIPT_DIR/templates/cpp.template" "$HOME_VIM/templates/cpp.template"
    echo "Copied C++ template"
elif [[ -f "$SCRIPT_DIR/cpptemplate.cpp" ]]; then
    cp "$SCRIPT_DIR/cpptemplate.cpp" "$HOME_VIM/templates/cpp.template"
    echo "Copied C++ template"
fi

echo ""
echo "=== Setup Complete ==="
echo "Run 'vim' to start with the CP configuration"
echo ""
echo "Useful commands:"
echo "  :TemplateCPP  - Insert C++ template (in Vim)"
echo "  <F5>         - Compile and run current file"
echo "  <F6>         - Compile with makeprg"
echo "  <Leader>c    - Toggle comment"
