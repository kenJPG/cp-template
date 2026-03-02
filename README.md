# cp-template

Minimal competitive programming template with Vim-focused workflow.

## What is included

- `cpptemplate.cpp`: base C++ template
- `templates/cpp.template`: template inserted from Vim
- `vimrc`: your custom Vim configuration
- `install_vim.sh`: Vim install script for macOS/Linux
- `setup.sh`: Unix setup script (links `~/.vimrc`, creates `~/.vim/templates`)
- `install_vim.ps1`: Vim install script for Windows
- `setup.ps1`: Windows setup script (copies `~/.vimrc`, creates `%USERPROFILE%\.vim\templates`)

## Quick start

### macOS / Linux

```bash
chmod +x install_vim.sh setup.sh
./install_vim.sh
./setup.sh
```

### Windows (PowerShell)

```powershell
powershell -ExecutionPolicy Bypass -File .\install_vim.ps1
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

## LLM agent installation guide

If an LLM agent opens this repository, use this exact flow.

### Unix/macOS agent flow

```bash
# from repo root
chmod +x install_vim.sh setup.sh
./install_vim.sh
./setup.sh

# verify
vim --version | head -n 1
```

### Windows agent flow (PowerShell)

```powershell
# from repo root
powershell -ExecutionPolicy Bypass -File .\install_vim.ps1
powershell -ExecutionPolicy Bypass -File .\setup.ps1

# verify
vim --version
```

### Agent checklist

- Run scripts from repository root.
- Do install first, then setup.
- If `g++` is missing, install it separately (needed for `<F5>` compile/run).
- If Vim is newly installed and not found, restart terminal and run `vim --version` again.

## Vim keys used most

- `<F5>`: compile and run current C++ file
- `<F6>`: run `:make` using configured `makeprg`
- `<Leader>t`: insert C++ template (`~/.vim/templates/cpp.template`)
- `<Leader>c`: prefix line(s) with `//`
- `<Leader>q`: quit all
- `<Leader>r`: reload `~/.vimrc`

## Notes

- `g++` must be available in your PATH for `<F5>`/`<F6>`.
- On Unix, output binary is `%<`; on Windows, `%<.exe`.
