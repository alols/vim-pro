" File: plugin/pro.vim
" Author: Albin Olsson
" URL: https://github.com/alols/vim-pro
"

command! -nargs=1 -complete=file Pload call pro#LoadFun(<q-args>) |call garbagecollect() |redraw!
command! -nargs=+ -complete=file Padd call pro#AddFun(<f-args>) |call garbagecollect() |redraw!
command! -nargs=+ -complete=customlist,pro#PComplete Prm call pro#RemoveFun(<f-args>)
command! Punload call pro#UnloadFun()
command! -nargs=+ -complete=customlist,pro#PComplete Pe e <args>
command! -nargs=1 Pgrep call pro#GrepFun(<q-args>)
command! Pls call pro#ListFiles()

augroup Pro
    au!
    autocmd BufWritePost * call pro#CheckFiles([expand("<afile>")])
augroup END

