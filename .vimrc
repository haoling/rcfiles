" □とか○の文字があってもカーソル位置がずれないようにする
if exists('&ambiwidth')
  set ambiwidth=double
endif

"行番号を表示
"set number

"(no)検索をファイルの末尾まで検索したら、ファイルの先頭へループする
set nowrapscan

"(no)vimのバックアップファイルとスワップファイル
set nobackup
set noswapfile

"コメントの色を変更
hi Comment ctermfg=2

" マウスモード有効
set mouse=a
" xtermとscreen対応
set ttymouse=xterm2

" 行番号を表示
set number

" タブを可視化
set list
set listchars=tab:>-

" カレント行ハイライトON
set cursorline
" アンダーラインを引く(color terminal)
highlight CursorLine cterm=underline ctermfg=NONE ctermbg=NONE
" アンダーラインを引く(gui)
highlight CursorLine gui=underline guifg=NONE guibg=NONE

" 黒背景端末に対応した色にする。
set bg=dark

" サーチハイライトををESC二回で消す
nnoremap <Esc><Esc> :nohlsearch<CR><Esc>

" モードラインを有効にする
set modeline

if !empty(glob("~/.vimrc.local"))
  source ~/.vimrc.local
endif
