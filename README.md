# Neovim dev environment — WSL2 + WezTerm dotfiles

A one-clone, two-script setup for a full **Neovim-based dev environment on
Windows 11**, used for two things:

- **Competitive programming in C++** (clangd + a `<F5>` build-and-run button)
- **Writing math notes / documents in Typst** (tinymist LSP + live inline image
  preview)

Everything is scripted and idempotent. Clone this repo onto a fresh Windows
machine, run **one Windows-side step** and **one WSL-side script**, and you're
fully configured.

---

## Architecture (and why WSL is required)

```
┌──────────────────────── Windows 11 host ────────────────────────┐
│                                                                  │
│   WezTerm  ──(default domain)──►  WSL2 / Ubuntu                  │
│   (GPU + kitty graphics protocol)                                │
│                                     │                            │
│                                     ▼                            │
│                        Neovim (LazyVim) + clangd + tinymist      │
│                        + g++ + typst + typst-preview             │
│                                                                  │
│   win32yank.exe  ◄──(clipboard bridge)──  Neovim "+y / "+p       │
└──────────────────────────────────────────────────────────────────┘
```

- **WezTerm** is the terminal emulator. It's GPU-accelerated and — critically —
  implements the **kitty graphics protocol**, which is what lets
  `typst-preview.nvim` draw rendered Typst pages as *inline images* inside
  Neovim.
- **WSL2 / Ubuntu** is where Neovim, the LSPs, the compiler and all tooling
  actually run. You edit files here even when they physically live under
  `/mnt/c/...`.
- **The Neovim config lives in this repo** (LazyVim-based, Lua) and is
  **symlinked** into `~/.config/nvim` inside WSL, so editing it in the repo
  takes effect live (after a restart of Neovim).

### Why not native Windows Neovim?

`typst-preview.nvim` renders inline images through the kitty graphics protocol,
which relies on **`ioctl`**. `ioctl` only works when Neovim itself is a genuine
Linux process. A native Windows Neovim throws `cannot resolve symbol 'ioctl'`
and inline Typst preview **literally cannot work**. Running the whole stack
inside WSL is the entire reason this repo is structured the way it is.

---

## Repo layout

```
.
├── README.md                  # this file
├── windows/
│   ├── install.ps1            # installs WSL, WezTerm, win32yank; deploys wezterm.lua
│   └── wezterm.lua            # WezTerm config (copied to %USERPROFILE%\.wezterm.lua)
├── wsl/
│   ├── install.sh             # installs Neovim, Typst, tinymist, clangd, etc.
│   └── clipboard-bridge.sh    # links win32yank.exe onto the WSL PATH
└── nvim/                       # symlinked to ~/.config/nvim
    ├── init.lua
    └── lua/
        ├── config/
        │   ├── options.lua    # vim.opt settings + .typ filetype
        │   ├── keymaps.lua    # custom keymaps (F5 build+run, etc.)
        │   └── autopairs.lua  # custom smart auto-pair engine
        └── plugins/
            ├── editor.lua     # disables mini.pairs (we use our own engine)
            ├── typst.lua      # tinymist LSP + typst-preview.nvim
            ├── cpp.lua        # clangd
            └── colorscheme.lua# light theme (catppuccin latte)
```

---

## Install — order of operations

### 1. Windows side (once, as Administrator)

Open an **elevated PowerShell** prompt in the repo root and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\install.ps1
```

This installs WSL2 + Ubuntu, WezTerm and win32yank (all via winget), and copies
`windows/wezterm.lua` to `%USERPROFILE%\.wezterm.lua`. It's idempotent — if WSL
or any package is already there, it skips it.

### 2. Reboot (only if the script says so)

A fresh WSL install requires a restart. If Ubuntu was already installed, no
reboot is needed and the script says so.

### 3. WSL side

Open **WezTerm** — it drops you straight into Ubuntu. On first launch Ubuntu
asks you to create a UNIX username/password. Then, from inside WSL, `cd` into
this repo (clone it in WSL, or navigate to it under `/mnt/c/...`) and run:

```bash
bash wsl/install.sh
```

This installs the latest stable Neovim, Typst, tinymist, clangd, poppler-utils
and the base toolchain; symlinks `nvim/` to `~/.config/nvim`; sets up the
clipboard bridge; and force-installs all Neovim plugins headlessly. It is safe
to re-run at any time.

---

## Day-to-day usage

`<leader>` is the **spacebar**.

| Key                | Does                                                        |
| ------------------ | ---------------------------------------------------------- |
| `<F5>`             | Save, compile the current C++ file (`g++ -std=c++17 -O2 -Wall`), and if it compiles, run it in an interactive terminal split |
| `<F6>`             | Save and `:make` the current C++ file                      |
| `<leader>tp`       | Start Typst inline preview                                  |
| `<leader>tq`       | Stop Typst preview                                          |
| `<leader>c`        | Toggle a leading `//` comment on the line / selection      |
| `<leader><space>`  | Clear search highlight                                      |
| `<leader>q`        | Quit all, without saving                                    |
| `<C-BS>`           | (insert / command mode) delete previous word               |

**Clipboard just works.** `clipboard=unnamedplus` is on and bridged to the real
Windows clipboard via win32yank, so a plain `y` copies to Windows and `p` pastes
from it — no `"+` prefix needed.

**Motions are plain vim.** `h/j/k/l` and `i` are unchanged (an old custom `ijkl`
scheme was deliberately dropped).

---

## Troubleshooting

These are the specific failure modes hit while setting this up by hand.

**`E492: Not an editor command: MasonInstall`**
The Mason command hasn't been lazy-loaded yet. Run `:Mason` once to force the
plugin to load, then the `:MasonInstall ...` command becomes available.

**`cannot resolve symbol 'ioctl'`**
Neovim is running as a **native Windows** process instead of inside WSL. Inline
Typst preview cannot work there — that's the whole reason this repo runs the
stack in WSL. Launch Neovim from the WSL/Ubuntu shell (i.e. from WezTerm's
default domain), not from a Windows `nvim.exe`.

**`no clipboard provider` / yanks don't reach Windows**
Usually a stale Neovim session started *before* win32yank was installed and
PATH-linked. Fully **restart Neovim** (not just `:q` a window) after any
clipboard tooling change. Verify the bridge with `command -v win32yank.exe` in
WSL and `:checkhealth provider` in Neovim; re-run `bash wsl/clipboard-bridge.sh`
if it's missing.

**`.typ` files get no LSP or preview**
Check that Neovim sees them as Typst: open a `.typ` file and run
`:set filetype?` — it must report `filetype=typst`. If not, the
`vim.filetype.add({ extension = { typ = "typst" } })` block in
`nvim/lua/config/options.lua` isn't loading. Also confirm `tinymist` is
installed (`:Mason`, or `command -v tinymist`) and `pdfinfo` exists
(`poppler-utils`).

**Preview opens but shows no image**
Confirm you're in **WezTerm** (kitty graphics), that `pdfinfo` is on PATH
(`poppler-utils`), and that `typst` itself runs (`typst --version`).

**WezTerm doesn't open into Ubuntu**
Your distro may not be named exactly `Ubuntu`. Run `wsl -l -q`, then set
`config.default_domain = "WSL:<your-distro>"` in `windows/wezterm.lua` (and copy
it to `%USERPROFILE%\.wezterm.lua`).
