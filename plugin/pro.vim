" File: plugin/pro.vim
" Author: Albin Olsson
" URL: https://github.com/alols/vim-pro
"

" These control ctags command extra command line options for different filetypes
let g:PTagExt = {}
let g:PTagExt['h'] = '--c++-kinds=+p --fields=+iaS --extra=+fq'
let g:PTagExt['cpp'] = '--c++-kinds=+p --fields=+iaS --extra=+q'

" So that a project can be stored in session script
set sessionoptions+=globals

command! -nargs=1 -complete=file Pcreate
            \ call pro#Create(<q-args>)

command! -nargs=1 -complete=file Pload
            \ call pro#Load(<q-args>) |
            \ call garbagecollect() |
            \ redraw!

command! -nargs=+ -complete=file Padd
            \ call pro#Add(<f-args>) |
            \ call garbagecollect() |
            \ redraw!

command! -nargs=+ -complete=customlist,pro#PComplete Prm
            \ call pro#Remove(<f-args>)

command! Punload
            \ call pro#Unload()

command! -nargs=+ -complete=customlist,pro#PComplete Pe
            \ e <args>

command! -nargs=1 Pgrep
            \ call pro#Grep(<q-args>)

augroup Pro
    au!

    autocmd BufWritePost *
            \ call pro#CheckFiles([expand("<afile>")])

    autocmd SessionLoadPost *
            \ if exists("g:PProjectFile") |
            \     call pro#Load(g:PProjectFile) |
            \     call garbagecollect() |
            \     redraw! |
            \ endif

augroup END

" Suggested mappings
" Leader-a  =  Find all occurances of word under cursor
"              and open the quickfix-window
nnoremap <Leader>a :exec "silent Pgrep /\\<".expand('<cword>')."\\>/gj"<CR>:cw<CR>
