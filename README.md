# Neovim dev environment — native Windows dotfiles

A one-clone, one-script setup for a full **Neovim-based dev environment on
Windows 11**, used for two things:

- **Competitive programming in C++** (clangd + a `<F5>` build-and-run button)
- **Writing math notes / documents in Typst** (tinymist LSP + live preview in
  your browser)

Everything is scripted and idempotent. Clone this repo onto a fresh Windows
machine, run **one script**, and you're fully configured. No WSL, no Linux VM,
no second OS to keep in sync — everything runs natively on Windows.

---

## Architecture

```
┌────────────────────────── Windows 11 ───────────────────────────┐
│                                                                  │
│   Neovim (LazyVim) ── clangd + tinymist + g++ (WinLibs) + typst │
│        │                                                        │
│        ├──► <F5> build+run ──► terminal split (interactive)     │
│        └──► <leader>tp ──► typst-preview.nvim ──► your browser  │
│                             (local HTTP + WebSocket server)      │
│                                                                  │
│   win32yank.exe (bundled with Neovim) ── clipboard, no setup     │
└──────────────────────────────────────────────────────────────────┘
```

- **Neovim runs natively on Windows.** No WSL, no Linux VM.
- **Typst preview renders in your default browser**, not inline in the
  terminal. Inline terminal image rendering (the kitty graphics protocol) was
  the original plan, but it depends on the terminal accurately reporting
  per-cell pixel size — unreliable in practice, and a genuine dead end under
  WSL specifically (see "Why not inline terminal preview?" below for the full
  story, kept for the record). A local web server + browser tab sidesteps all
  of that, and it's also what let this whole setup drop WSL entirely.
- **The Neovim config lives in this repo** (LazyVim-based, Lua) and is
  **symlinked** into `%LOCALAPPDATA%\nvim`, so editing it in the repo takes
  effect live (after a restart of Neovim).
- **Two separate C++ toolchains, on purpose**: `clangd` (LSP, from LLVM) for
  editor diagnostics, and real **GCC** (via WinLibs/MinGW) for the actual
  compile. Competitive-programming judges (Codeforces etc.) run GCC, and
  contest templates lean on GCC-only features — `#include <bits/stdc++.h>`
  and `#pragma GCC optimize/target` — that clang doesn't support the same way.
  clangd's diagnostics are close enough to GCC's behavior to be useful despite
  the mismatch.

### Why not inline terminal preview?

Kept here because it's a useful cautionary tale if you're tempted to revisit
it: inline terminal image preview (via a terminal graphics protocol, and
originally attempted through WSL2 + WezTerm specifically) depends on the
terminal correctly reporting the pixel size of a single character cell. Under
WSL2, the kernel's `TIOCGWINSZ` ioctl never fills in that pixel-size field —
a still-open bug (see `microsoft/WSL#12265` if you want to check whether it's
since been fixed) — which broke image sizing outright and, once patched
around with an estimate, produced blurry or wrongly-scaled output with no
reliable way to query the real value from inside WSL. Browser-based preview
has none of these problems: the browser knows its own pixel dimensions fine.

---

## Repo layout

```
.
├── README.md                  # this file
├── install.cmd                 # double-click this: elevates + runs install.ps1
├── install.ps1                 # the one setup script (winget installs + symlink + plugin sync)
└── nvim/                       # symlinked to %LOCALAPPDATA%\nvim
    ├── init.lua
    └── lua/
        ├── config/
        │   ├── options.lua    # vim.opt settings + .typ filetype
        │   ├── keymaps.lua    # custom keymaps (F5 build+run, etc.)
        │   └── autopairs.lua  # custom smart auto-pair engine
        └── plugins/
            ├── editor.lua     # disables mini.pairs (we use our own engine)
            ├── completion.lua # disables blink.cmp's ghost-text preview
            ├── typst.lua      # tinymist LSP + typst-preview.nvim (browser)
            ├── cpp.lua        # clangd
            └── colorscheme.lua# light theme (catppuccin latte)
```

---

## Install

**Double-click `install.cmd`** in the repo root. It relaunches `install.ps1`
elevated (you'll get the normal UAC prompt) and leaves the window open so you
can read the log. (Double-clicking the `.ps1` directly just opens Notepad —
that's a Windows security default — hence the `.cmd` wrapper.)

Or, equivalently, from an **elevated PowerShell** prompt in the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

This installs, all via `winget` (idempotent — already-installed packages are
skipped):

- **Neovim** — also bundles `win32yank.exe`, so clipboard support needs no
  extra setup at all.
- **Neovide** — GUI frontend for Neovim; the recommended way to launch (see
  below).
- **JetBrainsMono Nerd Font** — LazyVim's UI icons need a Nerd Font.
- **Typst** — the compiler CLI (for `<leader>te` PDF export).
- **Tinymist** — the Typst language server.
- **clangd** — the C++ language server.
- **WinLibs (GCC/MinGW)** — a real `g++`, not clang. See the architecture
  note above for why this matters.
- **ripgrep, fd** — used by LazyVim's fuzzy pickers.

Then it symlinks `nvim/` from this repo to `%LOCALAPPDATA%\nvim` (backing up
any existing config it finds first), and force-syncs all Neovim plugins
headlessly so the first real launch isn't the one waiting on downloads.

When it finishes, launch **Neovide** from the Start menu (recommended), or run
`nvim` from a **new Windows Terminal** window.

> **Do not run `nvim` inside plain `cmd.exe`** (the legacy console/conhost).
> Its fonts can't render LazyVim's Nerd Font icons (you get `?`-in-diamond
> boxes everywhere) and its terminal input handling is flaky — typing into the
> `<F5>` run split can silently not work. Neovide is a native GUI (the modern
> GVim equivalent): GPU-accelerated, launches from the Start menu, no terminal
> in the loop at all. Windows Terminal also works fine — set its font to
> `JetBrainsMono NF` (installed by this script) or the bundled
> `Cascadia Code NF`.

---

## Day-to-day usage

`<leader>` is the **spacebar**.

| Key                | Does                                                        |
| ------------------ | ---------------------------------------------------------- |
| `<F5>`             | Save, compile the current C++ file (`g++ -std=c++17 -O2 -Wall`), and if it compiles, run it in an interactive terminal split |
| `<F6>`             | Save and `:make` the current C++ file                      |
| `<leader>tp`       | Start Typst preview (opens in your browser)                |
| `<leader>tq`       | Stop Typst preview                                          |
| `<leader>te`       | Export the current Typst file to PDF and open it            |
| `<leader>c`        | Toggle a leading `//` comment on the line / selection      |
| `<leader><space>`  | Clear search highlight                                      |
| `<leader>q`        | Quit all, without saving                                    |
| `<C-BS>`           | (insert / command mode) delete previous word               |

**Clipboard just works.** `clipboard=unnamedplus` is on, and Neovim's Windows
build bundles `win32yank.exe`, so a plain `y` copies to the real Windows
clipboard and `p` pastes from it — no `"+` prefix, no extra setup.

**Motions are plain vim.** `h/j/k/l` and `i` are unchanged (an old custom
`ijkl` scheme was deliberately dropped).

---

## Troubleshooting

**`?`-in-diamond symbols all over the UI**
The font can't render LazyVim's Nerd Font icons. Launch via Neovide (which is
configured to use `JetBrainsMono NF`), or if you're in a terminal, make sure
it's Windows Terminal with a Nerd Font set — not plain `cmd.exe`, whose fonts
can't do this at all.

**`<F5>` opens the run split but typing does nothing**
Almost always: you're running `nvim` inside legacy `cmd.exe`/conhost, whose
ConPTY input handling is unreliable. Use Neovide or Windows Terminal. (The
run split is a normal terminal buffer — if you ever land in Normal mode, `i`
re-enters typing mode, and `<C-\><C-n>` gets you back out.)

**`E492: Not an editor command: MasonInstall`**
The Mason command hasn't been lazy-loaded yet. Run `:Mason` once to force the
plugin to load, then the `:MasonInstall ...` command becomes available.

**`<leader>tp` pauses for a while the first time**
Expected — `typst-preview.nvim` downloads its own pinned copies of `tinymist`
and `websocat` into `stdpath('data')/typst-preview` on first use. Needs
`curl`, which ships built into Windows 10 (1803+) and Windows 11 by default.
Subsequent runs are instant.

**No browser tab opens**
Check `:messages` for errors from `typst-preview.nvim`. Confirm `typst
--version` works from a plain terminal (proves the PATH/install is fine
outside Neovim). If a tab still doesn't open, the URL is also printed in
`:messages` — open it manually to confirm the server side is working.

**`no clipboard provider` / yanks don't reach elsewhere**
Usually a stale Neovim session started *before* Neovim itself was
(re)installed. Fully **restart Neovim** (not just `:q` a window). Verify with
`:checkhealth provider` — it should report `win32yank.exe` found.

**`.typ` files get no LSP or preview**
Check that Neovim sees them as Typst: open a `.typ` file and run
`:set filetype?` — it must report `filetype=typst`. If not, the
`vim.filetype.add({ extension = { typ = "typst" } })` block in
`nvim/lua/config/options.lua` isn't loading. Also confirm `tinymist` is on
PATH (`tinymist --version` in a plain terminal).

**`g++`/`gdb`/etc. not found right after running `install.ps1`**
`winget` updates the PATH for *new* shells, not the one that's already open.
Open a new terminal window and try again.
