if filereadable($VIMRUNTIME . '/vimrc_example.vim')
  source $VIMRUNTIME/vimrc_example.vim
endif

" Use the internal diff if available.
" Otherwise use the special 'diffexpr' for Windows.
if &diffopt !~# 'internal'
  set diffexpr=MyDiff()
endif
function MyDiff()
  let opt = '-a --binary '
  if &diffopt =~ 'icase' | let opt = opt . '-i ' | endif
  if &diffopt =~ 'iwhite' | let opt = opt . '-b ' | endif
  let arg1 = v:fname_in
  if arg1 =~ ' ' | let arg1 = '"' . arg1 . '"' | endif
  let arg1 = substitute(arg1, '!', '\!', 'g')
  let arg2 = v:fname_new
  if arg2 =~ ' ' | let arg2 = '"' . arg2 . '"' | endif
  let arg2 = substitute(arg2, '!', '\!', 'g')
  let arg3 = v:fname_out
  if arg3 =~ ' ' | let arg3 = '"' . arg3 . '"' | endif
  let arg3 = substitute(arg3, '!', '\!', 'g')
  if $VIMRUNTIME =~ ' '
    if &sh =~ '\<cmd'
      if empty(&shellxquote)
        let l:shxq_sav = ''
        set shellxquote&
      endif
      let cmd = '"' . $VIMRUNTIME . '\diff"'
    else
      let cmd = substitute($VIMRUNTIME, ' ', '" ', '') . '\diff"'
    endif
  else
    let cmd = $VIMRUNTIME . '\diff'
  endif
  let cmd = substitute(cmd, '!', '\!', 'g')
  silent execute '!' . cmd . ' ' . opt . arg1 . ' ' . arg2 . ' > ' . arg3
  if exists('l:shxq_sav')
    let &shellxquote=l:shxq_sav
  endif
endfunction

" ==========================================
" --- CUSTOM CONFIGURATION STARTS HERE ---
" ==========================================

" --- GVim Settings (if running GUI) ---
if has('gui_running')
    " GUI options - disable menu, toolbar, scrollbars
    set guioptions-=m
    set guioptions-=T
    set guioptions-=r
    set guioptions-=R
    set guioptions-=l
    set guioptions-=L
    " Start maximized on Windows
    if has('win32') || has('win64')
        au GUIEnter * simalt ~x
    endif
    " Set font (adjust as needed)
    set guifont=Consolas:h11
    " Disable toolbar icons, use text
    set toolbariconsize=hide
endif

" --- Display & Basics ---
set number
set belloff=all

set tabstop=4
set shiftwidth=4
set expandtab
set softtabstop=4

" CRITICAL: Allows backspacing over auto-indents, line breaks, and start of insert
set backspace=indent,eol,start

" --- Better C++ indentation ---
filetype plugin indent on
set autoindent
set cindent
set cinoptions={0,1s,t0,n-2,p2s,(03s,=.5s,>1s,=1s,:1s

" ==========================================
" --- IDE-LIKE AUTO-PAIRING ENGINE ---
" ==========================================

" 1. Smart Open: Only auto-close if at the end of a line or before whitespace/closing brackets
function! SmartOpen(open, close)
    let l:line = getline('.')
    let l:col = col('.')
    " If at EOL, or next char is space, tab, or a closing bracket, auto-pair
    if l:col > strlen(l:line) || l:line[l:col-1] =~ '[\s\}\]\)]'
        return a:open . a:close . "\<Left>"
    else
        " Otherwise, just insert the opening bracket (prevents ()myVar)
        return a:open
    endif
endfunction

" 2. Smart Close: Step over existing closing brackets instead of duplicating them
function! SmartClose(close)
    let l:line = getline('.')
    let l:col = col('.')
    if l:col <= strlen(l:line) && l:line[l:col-1] == a:close
        return "\<Right>"
    else
        return a:close
    endif
endfunction

" 3. Smart Quote: Prevents auto-pairing for contractions (like don't)
function! SmartQuote(quote)
    let l:line = getline('.')
    let l:col = col('.')
    
    " Step over if next char is the quote
    if l:col <= strlen(l:line) && l:line[l:col-1] == a:quote
        return "\<Right>"
    endif

    " If it's a single quote and the previous char is a letter, treat as contraction
    if a:quote == "'" && l:col > 1 && l:line[l:col-2] =~ '[a-zA-Z]'
        return a:quote
    endif

    " Otherwise, apply the SmartOpen logic
    if l:col > strlen(l:line) || l:line[l:col-1] =~ '[\s\}\]\)]'
        return a:quote . a:quote . "\<Left>"
    else
        return a:quote
    endif
endfunction

" 4. Smart Backspace: Deletes both brackets if they are completely empty
function! SmartBackspace()
    let l:line = getline('.')
    let l:col = col('.')
    if l:col > 1
        let l:prev = l:line[l:col-2]
        let l:next = l:line[l:col-1]
        " If cursor is strictly between empty pairs, delete the right one too
        if (l:prev == '{' && l:next == '}') || 
         \ (l:prev == '[' && l:next == ']') || 
         \ (l:prev == '(' && l:next == ')') || 
         \ (l:prev == '"' && l:next == '"') || 
         \ (l:prev == "'" && l:next == "'")
            " <Del> removes the right char, <BS> removes the left char
            return "\<Del>\<BS>"
        endif
    endif
    return "\<BS>"
endfunction

" 5. Smart Enter: Snaps braces to IDE formatting block
function! SmartEnter()
    let l:line = getline('.')
    let l:col = col('.')
    if l:col > 1 && l:line[l:col-2] == '{' && l:line[l:col-1] == '}'
        return "\<CR>\<Esc>O"
    else
        return "\<CR>"
    endif
endfunction

" --- Apply Auto-Pairing Maps ---
inoremap <expr> ( SmartOpen('(', ')')
inoremap <expr> [ SmartOpen('[', ']')
inoremap <expr> { SmartOpen('{', '}')

inoremap <expr> ) SmartClose(')')
inoremap <expr> ] SmartClose(']')
inoremap <expr> } SmartClose('}')

inoremap <expr> ' SmartQuote("'")
inoremap <expr> " SmartQuote('"')

inoremap <expr> <BS> SmartBackspace()
inoremap <expr> <CR> SmartEnter()

" ==========================================
" --- CUSTOM MOVEMENT & BEHAVIOR ---
" ==========================================

" Movement (Normal & Visual)
nnoremap i <Up>
nnoremap k <Down>
nnoremap j <Left>
vnoremap i <Up>
vnoremap k <Down>
vnoremap j <Left>

" Fast 7-line movements
nnoremap I 7<Up>
vnoremap I 7<Up>
nnoremap K 7<Down>
vnoremap K 7<Down>
nnoremap J 7<Left>
vnoremap J 7<Left>
nnoremap L 7<Right>
vnoremap L 7<Right>

" Insert Mode & Text Objects (Safely replacing 'i')
nnoremap h i
nnoremap H I
vnoremap h i
onoremap h i
vnoremap H I

" Ctrl+Backspace deletes previous word
inoremap <C-BS> <C-w>
cnoremap <C-BS> <C-w>

" Quick template insertion
nnoremap <Leader>t :0r ~/.vim/templates/cpp.template<CR>

" Toggle comment (simplistic)
nnoremap <Leader>c :s/^/\/\//<CR>:noh<CR>
vnoremap <Leader>c :s/^/\/\//<CR>:noh<CR>

nnoremap <F6> :w<CR>:make<CR>

" Persistent undo & Search improvements
set undofile
set undodir=~/.vim/undodir
set incsearch
set hlsearch
nnoremap <Leader><space> :nohlsearch<CR> 

command! TemplateCPP :0r ~/.vim/templates/cpp.template

" --- Speed: Disable safe keys for faster typing ---
" (Already have backspace enabled above)

" --- Match highlighting for brackets ---
set showmatch
set matchtime=1

" --- Quick exit ---
nnoremap <Leader>q :qa!<CR>

" --- Reload vimrc ---
nnoremap <Leader>r :source ~/.vimrc<CR>

" --- Windows: Use .exe extension, Unix: no extension ---
if has('win32') || has('win64')
    nnoremap <F5> :w<CR>:!g++ -std=c++17 -O2 -Wall "%" -o "%<.exe" && "%<.exe"<CR>
    inoremap <F5> <Esc>:w<CR>:!g++ -std=c++17 -O2 -Wall "%" -o "%<.exe" && "%<.exe"<CR>
    vnoremap <F5> :<C-u>w<CR>:!g++ -std=c++17 -O2 -Wall "%" -o "%<.exe" && "%<.exe"<CR>
    set makeprg=g++\ -std=c++17\ -O2\ -Wall\ %\ -o\ %<.exe
else
    nnoremap <F5> :w<CR>:!g++ -std=c++17 -O2 -Wall "%" -o "%<" && "./%<"<CR>
    inoremap <F5> <Esc>:w<CR>:!g++ -std=c++17 -O2 -Wall "%" -o "%<" && "./%<"<CR>
    vnoremap <F5> :<C-u>w<CR>:!g++ -std=c++17 -O2 -Wall "%" -o "%<" && "./%<"<CR>
    set makeprg=g++\ -std=c++17\ -O2\ -Wall\ %\ -o\ %<
endif
