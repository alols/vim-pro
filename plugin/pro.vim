" File: plugin/pro.vim
" Maintainer: Albin Olsson
"

command! -nargs=1 Pgrep call pro#GrepFun(<q-args>)
command! -nargs=1 -complete=file Pload call pro#LoadFun(<q-args>)
command! Punload call pro#UnloadFun()
command! -nargs=+ -complete=file Padd call pro#ExpandFiles(function("pro#AddFun"), <f-args>)
command! -nargs=+ -complete=customlist,pro#PComplete Prm call pro#ExpandFiles(function("pro#RemoveFun"), <f-args>)
command! Pls call pro#ListFiles()
command! -nargs=1 Pdo call pro#DoFun(<q-args>)
command! -nargs=+ -complete=customlist,pro#PComplete Pe e <args>

augroup Pro
    au!
    autocmd BufWritePost * call pro#CheckFile(expand("<afile>"), 0)
augroup END
