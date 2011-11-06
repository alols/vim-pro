fun! ProGrepFun(grepcommand)
    if exists("g:ProFiles")
        let grepcommand = "vimgrep ".a:grepcommand.' '.join(keys(g:ProFiles), ' ')
    "    for s in g:VimProPro.VIM_GREP
    "        let grepcommand = grepcommand.' '.join(g:VimProPro[s], ' ')
    "    endfor
        echom grepcommand
        try
            exec grepcommand
        catch /E480/
            echom "Pattern not found in project"
            return
        endtry
        exec "2match Search ".substitute(a:grepcommand, "\\(^/.*/\\).*$", "\\1", "")
    endif
endfun
command! -nargs=1 ProGrep call ProGrepFun("<args>")

fun! ProGrepWord(word)
    normal! gew
    call ProGrepFun("/\\<".a:word."\\>/gj")
endfun
nmap <F9> :call ProGrepWord(expand("<cword>"))<cr>
nmap <F10> :cc 1<cr>

fun! ProTagUpdate(fname)
    if exists("g:ProTags")
        let fname = fnamemodify(a:fname, ":p")
        let ftype = fnamemodify(a:fname, ":e")
        " TODO ctags command line depends on filetype
        if ftype == 'c' || ftype == 'h' || ftype == 'cpp' || ftype == 'py' || ftype == 'vim'
            exec "keepalt silent e ".g:ProTags
            exec "silent g/".escape(fname,'/')."/d"
            keepalt silent w
            keepalt silent bwipe
            exec "silent !ctags -f ".g:ProTags." -a ".fname
        endif
    endif
endfun

fun! ProCheckFile(fname)
    if exists("g:ProFiles")
        let fname = fnamemodify(a:fname, ":p")
        let readable = filereadable(fname)
        let ftime = getftime(fname)
        if has_key(g:ProFiles, fname)
            if readable
                if g:ProFiles[fname] == ftime
                    " fname is already part of project
                    " and is unmodified
                    return
                endif
            else
                call remove(g:ProFiles, fname)
                return
            endif
        elseif !readable
            return
        endif
        let g:ProFiles[fname] = ftime
        call ProTagUpdate(fname)
        call ProSaveFun()
    endif
endfun

fun! ProSaveFun()
    if exists("g:ProFile")
        let lines = []
        for i in items(g:ProFiles)
            call add(lines, join(i, "\t"))
        endfor
        call writefile(lines, g:ProFile)
    endif
endfun

fun! ProLoadFun(fname)
    let g:ProFile = fnamemodify(a:fname, ":p")
    let g:ProDir = fnamemodify(g:ProFile, ":p:h")
    let g:ProTags = g:ProDir."/tags"
    let g:ProFiles = {}
    if filereadable(g:ProFile)
        for line in readfile(g:ProFile)
            let tokens = split(line, "\t")
            let g:ProFiles[tokens[0]]=tokens[1]
        endfor
        for k in keys(g:ProFiles)
            call ProCheckFile(k)
        endfor
    endif
endfun
command! -nargs=1 ProLoad call ProLoadFun(expand("<args>"))

fun! ProUnloadFun()
    unlet g:ProFile g:ProDir g:ProTags g:ProFiles
endfun

fun! ProAddFun(fname)
    if !filereadable(a:fname)
        echohl Error
        echom "File does not exist."
        echohl None
        return
    endif
    if !exists("g:ProFiles")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    call ProCheckFile(a:fname)
endfun
command! -nargs=1 ProAdd call ProAddFun(expand("<args>"))

fun! ProRemoveFun(fname)
    if !exists("g:ProFiles")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    let fname = fnamemodify(a:fname, ":p")
    if has_key(g:ProFiles, fname)
        call remove(g:ProFiles, fname)
    endif
endfun
command! -nargs=1 ProRemove call ProRemoveFun(expand("<args>"))

augroup Pro
    au!
    autocmd BufWritePost * call ProCheckFile(expand("<afile>"))
augroup END

