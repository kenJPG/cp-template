#!/bin/bash

set -euo pipefail

echo "=== Installing Vim ==="

detect_os() {
    if [[ "${OSTYPE:-}" == "darwin"* ]]; then
        echo "macos"
        return
    fi

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "${ID:-}" in
            ubuntu|debian|linuxmint|pop) echo "debian" ;;
            fedora|rhel|centos) echo "fedora" ;;
            arch|manjaro|endeavouros) echo "arch" ;;
            *) echo "unknown" ;;
        esac
        return
    fi

    echo "unknown"
}

install_mac() {
    if command -v brew >/dev/null 2>&1; then
        brew install vim
        return
    fi

    echo "Homebrew not found. Install Homebrew first: https://brew.sh"
    exit 1
}

install_debian() {
    sudo apt update
    sudo apt install -y vim
}

install_fedora() {
    sudo dnf install -y vim-enhanced
}

install_arch() {
    sudo pacman -Syu --noconfirm vim
}

OS="$(detect_os)"
echo "Detected OS: ${OS}"

case "${OS}" in
    macos) install_mac ;;
    debian) install_debian ;;
    fedora) install_fedora ;;
    arch) install_arch ;;
    *)
        echo "Unsupported distro for automatic install. Install Vim manually."
        exit 1
        ;;
esac

if ! command -v vim >/dev/null 2>&1; then
    echo "ERROR: Vim installation failed or is not in PATH yet."
    exit 1
fi

echo "=== Vim installed successfully ==="
vim --version | head -n 1
echo "Run './setup.sh' to set up the vimrc configuration"
