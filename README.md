# Neovim technical IDE - native Windows dotfiles

This repo is a Windows-native Neovim setup for six daily workflows:

- shared C++/Java/Python template generation in both the shell and Neovim
- C++ competitive programming with a reliable `g++` build/run loop
- Typst writing with Tinymist LSP, browser preview, and manual PDF export
- Lightweight class notes in Typst or Markdown without a PKM framework
- Java 17 projects with JDTLS completion, diagnostics, navigation, and refactoring
- Python projects with BasedPyright, Ruff, and virtual-environment selection

Everything runs on Windows directly. No WSL or Linux VM is required.

## Install

Double-click `install.cmd` (recommended). It runs machine setup with UAC, then
returns to your normal user before installing editor plugins.

The manual equivalent is two commands: first run this in an elevated PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Then close the elevated shell and run this in a normal PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

Both phases are idempotent. Together they will:

- install Git, Neovim, Neovide, JetBrainsMono Nerd Font, Typst, Tinymist,
  clangd, WinLibs `g++`, Temurin JDK 17, 21, and 25, Python 3.13,
  tree-sitter CLI,
  StyLua, ripgrep, and fd via
  `winget`
- refresh PATH in-process and fail clearly if required tools are still missing
- symlink `nvim/` from this repo to `%LOCALAPPDATA%\nvim`, backing up any
  existing config first
- return to the normal user before running plugin code
- install `templatecpp`, `templatejava`, and `templatepy` into
  `%LOCALAPPDATA%\Programs\cp-template\bin`, copy their shared templates and
  CLI support files together, and add that user-local bin directory to PATH
- install version-pinned JDTLS, BasedPyright, and Ruff as editor-only Mason tools
- configure Neovide to open in your Windows Desktop directory with direct,
  non-animated cursor and scrolling behavior; the editor selects the
  no-ligature `JetBrainsMonoNL NF` family so operators such as `!=` and `<=`
  remain literal characters
- restore/install the lockfile's pinned plugins, synchronously install core
  parsers that build reliably with WinLibs, inspect plugin task errors, and
  verify a clean second start

Launch **Neovide** after install, or start `nvim` from a fresh Windows Terminal
window. Neovide is the recommended daily driver because it avoids legacy console
input/font issues and already uses the configured Nerd Font. Start-menu launches
open in your Windows Desktop directory.

The template commands are installed for the current user only. `bootstrap.ps1`
updates the current process PATH immediately; a **new** Windows Terminal or
PowerShell window will also pick them up automatically.

## Template toolkit: shell + Neovim share the same files

Canonical templates live under the repo's root `templates/` directory. Neovim
reads them directly; `bootstrap.ps1` refreshes the shell commands' user-local
copy. This keeps one source of truth while allowing the shell commands to work
from any directory without depending on the repo staying at the same path.

Quick shell examples from any Windows terminal after install:

```powershell
templatecpp
templatecpp contest/round-1/solve
templatejava .\practice\PracticeSession
templatepy ".\scratch dir"
```

Behavior and safety rules:

- default targets are `main.cpp`, `Main.java`, and `main.py`
- suffix-less targets get the language suffix appended automatically
- an existing directory target gets the default filename inside it
- parent directories are created automatically
- existing files are **never** overwritten unless you pass `-f` / `--force`
- Java derives `public class` from the output filename stem and rejects invalid
  identifiers early

Each command prints the created absolute path plus a short next-step hint such
as the Java compile/run command.

Inside Neovim, open a blank `cpp`, `java`, or `python` buffer and press
`<leader>it`. The matching template is inserted from the same canonical source,
the cursor lands inside `solve()`, and Neovim enters insert mode. Buffer-local
commands are:

- `:TemplateCpp`
- `:TemplateJava`
- `:TemplatePython`
- `:CppTemplate` (C++ compatibility alias)
- `:TemplateCPP` (historical Vim compatibility alias)

Templates only insert into a truly blank buffer. Nonblank buffers are left
unchanged.

## Update flow

After `git pull` or any local template/config change, re-run:

```powershell
powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
```

That refreshes the user-local template commands, PATH for the current process,
Neovim plugin/bootstrap validation, and other managed user-side setup.

## Daily workflows

### 1) C++: build, quickfix, and one reusable scratch panel

Open a `*.cpp` buffer and use the buffer-local keys below:

- `<F6>` - save and build asynchronously
- `<F5>` - save, build asynchronously, then open a bottom input panel for the compiled `.exe`
- `<leader>it` - insert the shared C++ template into a blank C++ buffer
- `<leader>rx` - stop the running program if needed and close its run panel
- `<leader>rp` - toggle the run panel between the bottom and the right side
  (also `:CppPanelSide`; works from the panel too, and moves it live without
  restarting the program; set `vim.g.cpp_panel_position = "right"` to make
  right the startup default)

Details that matter:

- `g++` is invoked through `vim.system({...})`, not a shell string, so paths
   with spaces are preserved.
- The compile command is `g++ -std=gnu++20 -O2 -Wall -Wextra`.
- clangd queries that same resolved `g++.exe` for MinGW/libstdc++ headers, so
  `bits/stdc++.h`, `cout`, and other contest-standard symbols diagnose correctly.
- C/C++ format-on-save is disabled, and clangd has no fallback style, so compact
  contest macros and the inserted template are preserved exactly. A project can
  still opt into formatting by providing its own `.clang-format`.
- Build artifacts go under `stdpath('cache')/cpp-build/`, not beside the source
  file.
- Compile failures populate quickfix and open it automatically.
- Successful runs reuse one bottom panel area.
- After a successful build, that panel opens as a normal editable input buffer.
  Type or paste stdin directly, then press `<F5>` in the panel to submit.
- Submission runs the exe in a terminal in the same bottom area and pre-feeds
  your input, but leaves stdin open. Batch problems behave as before: input is
  auto-typed and output appears. A nonzero exit or crash leaves a permanent
  `[runtime error]` footer with the exit reason in the panel and also raises a
  warning notification; stderr remains visible immediately above the footer.
  Interactive problems just work: keep typing in the terminal to answer the
  program's queries. Submitting empty input starts the program with nothing
  fed, ready for a fully live session.
- Programs that read until EOF need an explicit end-of-input keystroke in the
  terminal: `Ctrl-Z` then `Enter` on Windows (`Ctrl-D` on Unix). Contest
  problems with explicit counts never need this.
- While focused on the input panel, `<Esc>` returns to the launching source
  window, `<F5>` submits, and `<C-q>` closes the panel.
- In the run terminal, typing goes to the program; `<Esc>` drops to normal
  mode (press `<Esc>` again to return to the source window), `<F5>` stops the
  program and reopens the preserved input for a rerun, and `<C-q>` (or `q` in
  normal mode) closes the panel.
- A previous still-running program is killed and awaited before rebuilding the
  same cached executable path, so repeated runs stay deterministic and do not
  leave stale callbacks or locked `.exe` files behind.
- Large motions such as `gg` and `G` are immediate; both Neovide animation and
  LazyVim's inherited Snacks smooth scrolling are disabled.
- Code windows use Neovim's fixed native number/sign gutter rather than a
  dynamically sized status column, preventing a stale oversized left margin.
- The editor uses Neovim's built-in `vim` colorscheme on a light background,
  matching the classic native gVim syntax colors without a theme plugin.
- C/C++ inferred-type inlay hints are disabled, and tabs/trailing spaces render
  as ordinary blank whitespace instead of inline type labels or `>`/`-` marks.
- Indentation guides are disabled. Smart auto-pairs (mini.pairs) are on:
  openers insert their closer with the cursor inside, typing an existing
  closer skips over it, backspace deletes a whole empty pair, Enter between
  `{}` opens an indented block, and quotes never pair inside strings or
  before a word character. Neovide adds only 6 px top and 4 px side padding.

Buffer-local commands for the same flow:

- `:CppBuild`
- `:CppBuildRun`
- `:CppTemplate` (compatibility alias for `:TemplateCpp`)
- `:TemplateCPP` (historical Vim compatibility alias)
- `:TemplateCpp`
- `:CppClose`

The template action refuses to overwrite a nonblank file and leaves the cursor
inside `solve()`. C++ actions are buffer-local; Markdown, Typst, and other
filetypes do not receive them.

### 2) Typst: preview in browser, export on demand

Open a `*.typ` file and use:

- `<leader>tp` - toggle browser preview
- `<leader>tq` - stop browser preview explicitly
- `<leader>te` - save, export PDF asynchronously, and open the PDF

Notes:

- Tinymist stays configured as a single-file-friendly LSP with `typstyle`
  formatting.
- Preview remains browser-based through `typst-preview.nvim`; no inline terminal
  graphics are involved.
- PDF export uses `vim.system({...})`, so source/output paths stay path-safe.
- Export failures and automatic-open failures are surfaced clearly.

### 3) Notes: quick class-note creation and search

Default notes root: `~/Documents/Notes`

- `<leader>nn` - create a timestamped Typst class note
- `<leader>nf` - find an existing `.typ` or `.md` note
- `:NotesNew [title]` - create/open a note directly
- `:NotesFind` - open the notes picker

Behavior:

- New class notes are stored under `~/Documents/Notes/class/<year>/<month>/`
- The title is prompted when omitted and turned into a safe filename slug
- Parent directories are created automatically
- Notes use a small Typst template with a title, timestamp, summary, and notes
  section
- If Snacks is available, note search uses its picker; otherwise it falls back
  to Neovim's built-in UI selection

Markdown and Typst buffers also get conservative local prose settings for class
notes: `wrap`, `linebreak`, `breakindent`, `spell`, and `spelllang=en_us`. They
are applied buffer-locally and do not leak into C++ buffers.

### 4) Java 17: project-aware editing

- Open a Java file inside a Maven, Gradle, or Ant project. JDTLS discovers the
  project root and keeps a separate workspace under Neovim's cache.
- Java 17 is the generic project compiler/runtime target. JDTLS runs on Java 21
  because current JDTLS releases require it; the installer configures both
  roles and also installs Java 25 for current Minecraft 26.x toolchains.
- Completion, diagnostics, rename, go-to-definition, import organization, and
  extract-variable/constant/method refactors are available through normal LSP
  and `<leader>c...` actions.
- `<F5>` saves and runs the current source directly with Java 17 source-file
  mode in a reusable terminal panel. This is ideal for standalone exercises;
  Maven/Gradle applications should keep using their project-defined run task.
- `<leader>it` or `:TemplateJava` inserts a simple single-file Java practice
  template with `BufferedReader`, `StringBuilder`, and a filename-derived public
  class.
- Debugging and Java test adapters are intentionally not installed yet. They add
  several packages and expensive project scans; add them only when needed.

This single-file Java mode is for exercises, interview practice, and competitive
programming. It is **not** a Minecraft mod project generator.

### 5) Python: typed, formatted project editing

- BasedPyright provides completion, navigation, and standard-level type checks.
- Ruff provides diagnostics, code actions, and formatting without overlapping
  Black/Flake8/isort processes.
- Create a `.venv` in the project when possible. Use `<leader>cv` to choose a
  different environment; the selection is cached by the Python extra.
- `<F5>` saves and runs the current file, preferring the interpreter selected by
  `<leader>cv`, then the project's `.venv`, then the installed system Python.
- `<leader>it` or `:TemplatePython` inserts a small typed `solve()`/`main()`
  starter that runs without stdin by default.

## Minecraft mod projects: use the official generators and toolchains

Keep the generic Java template for plain source files only. For actual Fabric or
NeoForge mod work, use the official project scaffolding and let Gradle manage
the Java toolchain per project.

- Current Fabric/NeoForge **26.x** projects use **JDK 25**
- Older **1.21.x** project docs use **JDK 21**
- Prefer the Gradle wrapper plus Java toolchains instead of changing your global
  Java install manually for each project

Official references:

- Fabric setup: https://docs.fabricmc.net/develop/getting-started/setting-up
- Fabric project creation: https://docs.fabricmc.net/develop/getting-started/creating-a-project
- NeoForge getting started: https://docs.neoforged.net/docs/gettingstarted/
- Gradle toolchains: https://docs.gradle.org/current/userguide/toolchains.html

## Key reference

`<leader>` is the spacebar.

| Key | Scope | Action |
| --- | --- | --- |
| `<F5>` | `cpp` buffer | Build, then open the C++ input panel |
| `<F5>` | `java` buffer | Save and run the current source as Java 17 |
| `<F5>` | `python` buffer | Save and run with the selected/project interpreter |
| `<F6>` | `cpp` buffer only | Build only |
| `<leader>it` | `cpp`, `java`, or `python` buffer | Insert the matching shared template into a blank file |
| `<leader>rx` | `cpp`, `java`, or `python` buffer | Stop and close its run panel |
| `<leader>rp` | `cpp` buffer / run panel | Toggle panel between bottom and right |
| `<leader>tp` | `typst` buffer only | Toggle Typst browser preview |
| `<leader>tq` | `typst` buffer only | Stop Typst preview |
| `<leader>te` | `typst` buffer only | Export PDF and open it |
| `<leader>nn` | global | Create a class note |
| `<leader>nf` | global | Find an existing note |
| `gcc` | normal | Toggle comment on the current line |
| `gc` | normal / visual | Toggle comment with a motion or selection |
| `<leader><space>` | global | Clear search highlight |
| `<leader>q` | global | Quit all without saving |
| `<C-BS>` | insert / command | Delete previous word |
| `<Esc>` | C++ input panel | Return to the source editor |
| `<F5>` | C++ input panel | Submit the buffer as pre-fed stdin |
| `<C-q>` | C++ input panel | Close the run panel |
| `<Esc>` | C++ run terminal | Leave live typing (again: back to editor) |
| `<F5>` | C++ run terminal | Stop program, reopen preserved input |
| `q` / `<C-q>` | C++ run terminal | Close the run panel |
| `<F5>` | Java/Python run terminal | Stop and rerun the source file |
| `<Esc>` | Java/Python run terminal (normal mode) | Return to the source editor |
| `<C-q>` | Java/Python run terminal | Stop and close the run panel |

## Validation and troubleshooting

Start with:

```vim
:checkhealth
```

Then verify the external tools directly in a new PowerShell or Windows Terminal:

```powershell
git --version
nvim --version
neovide --version
templatecpp --help
templatejava --help
templatepy --help
gcc --version
g++ --version
java --version
javac --version
python --version
clangd --version
typst --version
tinymist --version
tree-sitter --version
stylua --version
rg --version
fd --version
curl --version
```

Common issues:

- **Installer stops with a missing-tools list**: one or more `winget` installs
  did not land on PATH. Re-run `install.cmd` after
  fixing the reported package.
- **`<F5>` does nothing outside C++, Java, or Python**: expected. Run mappings
  are buffer-local to those filetypes; `<F6>` remains C++-only.
- **Compile errors disappear too quickly**: they should now be in quickfix. Use
  `:copen` if you closed the list.
- **clangd says `bits/stdc++.h` or `cout` is missing**: rerun `bootstrap.ps1` to
  regenerate `%LOCALAPPDATA%\clangd\config.yaml` from the active `g++.exe`, then
  restart Neovide. `:LspRestart` is enough after the config already exists.
- **The C++ panel is still on the input buffer**: expected until you press
  `<F5>` inside that panel. The source-buffer `<F5>` only compiles and opens the
  editable stdin scratch.
- **A program reads until EOF and never finishes**: stdin stays open so
  interactive problems work. Type `Ctrl-Z` then `Enter` in the run terminal to
  send EOF on Windows (`Ctrl-D` on Unix).
- **You want to tweak the same input again**: from the run terminal, press `<F5>`
  to reopen the preserved stdin text, edit it normally, and submit again.
- **`!=` or `<=` appears as one combined symbol**: restart Neovide and check
  `:set guifont?`; it should report `JetBrainsMonoNL NF:h11`.
- **Typst preview's first launch is slow**: expected. It uses the system
  Tinymist, but `typst-preview.nvim` still fetches its websocat helper on first
  use and needs `curl` available.
- **PDF export succeeds but no viewer opens**: the PDF path is shown in the
  notification; open it manually and check the Windows file association.
- **No Typst LSP or preview in `.typ` files**: confirm `:set filetype?` reports
  `typst`, then check `tinymist --version` and `typst --version` outside Neovim.

## Headless smoke tests

Run the lightweight config tests from the repo root:

```powershell
nvim --headless -u NONE "+lua dofile('tests/run.lua')" +qa
nvim --headless -u NONE "+lua dofile('tests/cpp_e2e.lua')" +qa
nvim --headless -u NONE "+lua dofile('tests/typst_e2e.lua')" +qa
nvim --headless -u NONE "+lua dofile('tests/notes_e2e.lua')" +qa
nvim --headless -u NONE "+lua dofile('tests/java_e2e.lua')" +qa
nvim --headless -u NONE "+lua dofile('tests/python_e2e.lua')" +qa
nvim --headless -u NONE "+lua dofile('tests/language_run_e2e.lua')" +qa
nvim --headless "+lua dofile('tests/language_lsp_e2e.lua')" +qa
python .\tests\template_cli_e2e.py
powershell -ExecutionPolicy Bypass -File .\tests\bootstrap_failure.ps1
```

They assert that:

- C++ `<F5>` / `<F6>` mappings are buffer-local and absent from Markdown/Typst
- prose options are local to Markdown/Typst and do not leak into C++
- the C++ compile argv keeps a source path with spaces as a single argv entry
- the real C++ runner compiles from a path with spaces, opens the scratch input
  panel, pre-feeds stdin into the run terminal, observes `42`, preserves input
  for rerun, answers an interactive prompt by typing into the live terminal,
  and safely rebuilds the same cached executable while cancelling a previous
  run on both Windows and Linux
- the real Typst export callback compiles a math note from a path with spaces
  and produces a non-empty PDF
- repeated same-title note creation produces unique files instead of overwriting
  an existing note
- Java sources compile with `javac --release 17` and run successfully
- Python sources run successfully from paths containing spaces
- the template CLI covers defaults, suffix appending, overwrite safety, spaced
  paths, Java class substitution, and compile/run smoke checks when toolchains
  exist
- Java/Python `<F5>` mappings stay buffer-local and produce real terminal output
- JDTLS, BasedPyright, and Ruff attach to minimal project fixtures
- bootstrap Lua/module failures force a nonzero Neovim process exit

The standalone compile/run tests print a skip message when their system runtime
is unavailable. The live LSP test fails when its repo-managed Mason tools are
missing, keeping bootstrap verification fail-closed.
