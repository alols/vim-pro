" File: plugin/pro.vim
" Author: Albin Olsson
" URL: https://github.com/alols/vim-pro
"

" These control ctags command extra command line options for different filetypes
let g:PTagExt = {}
let g:PTagExt['h'] = '--c++-kinds=+p --fields=+iaS --extra=+fq'
let g:PTagExt['cpp'] = '--c++-kinds=+p --fields=+iaS --extra=+q'

command! -nargs=1 -complete=file Pcreate call pro#CreateFun(<q-args>)
command! -nargs=1 -complete=file Pload call pro#LoadFun(<q-args>) |call garbagecollect() |redraw!
command! -nargs=+ -complete=file Padd call pro#AddFun(<f-args>) |call garbagecollect() |redraw!
command! -nargs=+ -complete=customlist,pro#PComplete Prm call pro#RemoveFun(<f-args>)
command! Punload call pro#UnloadFun()
command! -nargs=+ -complete=customlist,pro#PComplete Pe e <args>
command! -nargs=1 Pgrep call pro#GrepFun(<q-args>)

augroup Pro
    au!
    autocmd BufWritePost * call pro#CheckFiles([expand("<afile>")])
augroup END

