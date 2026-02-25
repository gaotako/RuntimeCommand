" RuntimeCommand vim configuration.
" Sourced by ~/.vimrc in the Docker home directory.

" ---- Display ----
syntax on                       " Enable syntax highlighting.
set number                      " Show line numbers.
set relativenumber              " Show relative line numbers.
set cursorline                  " Highlight the current line.
set showmatch                   " Highlight matching brackets.
set laststatus=2                " Always show the status line.
set ruler                       " Show cursor position in status line.
set showcmd                     " Show partial commands in status line.
set title                       " Set terminal title to filename.
set signcolumn=yes              " Always show the sign column.

" ---- Color ----
set background=dark             " Optimize colors for dark terminals.
set termguicolors               " Enable 24-bit color if supported.

" ---- Search ----
set hlsearch                    " Highlight search results.
set incsearch                   " Show matches as you type.
set ignorecase                  " Case-insensitive search.
set smartcase                   " Case-sensitive if uppercase is used.

" ---- Indentation ----
set autoindent                  " Copy indent from current line.
set smartindent                 " Smart autoindent for C-like languages.
set expandtab                   " Use spaces instead of tabs.
set tabstop=4                   " Tab width is 4 spaces.
set shiftwidth=4                " Indent width is 4 spaces.
set softtabstop=4               " Backspace deletes 4 spaces.

" ---- Editing ----
set backspace=indent,eol,start  " Allow backspace over everything.
set scrolloff=8                 " Keep 8 lines above/below cursor.
set sidescrolloff=8             " Keep 8 columns left/right of cursor.
set wrap                        " Wrap long lines.
set linebreak                   " Wrap at word boundaries.
set wildmenu                    " Enhanced command-line completion.
set wildmode=longest:full,full  " Complete longest common, then cycle.

" ---- Files ----
set encoding=utf-8              " Use UTF-8 encoding.
set fileencoding=utf-8          " Save files as UTF-8.
set noswapfile                  " Disable swap files.
set nobackup                    " Disable backup files.
set autoread                    " Auto-reload files changed outside vim.
set hidden                      " Allow switching buffers without saving.

" ---- Mouse ----
set mouse=a                     " Enable mouse in all modes.

" ---- Key Mappings ----
" Clear search highlighting with Escape.
nnoremap <Esc> :nohlsearch<CR>