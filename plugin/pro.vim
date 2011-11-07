fun! s:ProGrepFun(grepcommand)
    if !exists("s:files_dict")
        echohl Error
        echom "No project file loaded."
        echohl None
    elseif empty(s:files_dict)
        echohl Error
        echom "No files in project."
        echohl None
    else
        let grepcommand = "vimgrep ".a:grepcommand.' '.join(keys(s:files_dict), ' ')
        try
            exec grepcommand
        catch /E480/
            echom "Pattern not found in project"
            return
        endtry
        exec "2match Search ".substitute(a:grepcommand, "\\(^/.*/\\).*$", "\\1", "")
    endif
endfun
command! -nargs=1 ProGrep call s:ProGrepFun("<args>")

fun! s:ProTagUpdate(fname)
    if exists("s:tags_file")
        let fname = fnamemodify(a:fname, ":p")
        let ftype = fnamemodify(a:fname, ":e")
        " TODO ctags command line depends on filetype
        if ftype == 'c' || ftype == 'h' || ftype == 'cpp' || ftype == 'py' || ftype == 'vim'
            if filereadable(s:tags_file)
                let tfile = readfile(s:tags_file)
                let i = match(tfile, fname)
                while i >= 0
                    call remove(tfile, i)
                    let i = match(tfile, fname, i)
                endwhile
                call writefile(tfile, s:tags_file)
            endif
            exec "silent !ctags -f ".s:tags_file." -a ".fname
        endif
    endif
endfun

fun! s:ProCheckFile(fname)
    if exists("s:files_dict")
        let fname = fnamemodify(a:fname, ":p")
        let readable = filereadable(fname)
        let ftime = getftime(fname)
        if has_key(s:files_dict, fname)
            if readable
                if s:files_dict[fname] == ftime
                    " fname is already part of project
                    " and is unmodified
                    return
                endif
            else
                call remove(s:files_dict, fname)
                return
            endif
        elseif !readable
            return
        endif
        let s:files_dict[fname] = ftime
        call s:ProTagUpdate(fname)
        call s:ProSaveFun()
    endif
endfun

fun! s:ProSaveFun()
    if exists("s:project_file")
        let lines = []
        for i in items(s:files_dict)
            call add(lines, join(i, "\t"))
        endfor
        call writefile(lines, s:project_file)
    endif
endfun

fun! s:ProLoadFun(fname)
    let s:project_file = fnamemodify(a:fname, ":p")
    let s:root_dir = fnamemodify(s:project_file, ":p:h")
    let s:tags_file = s:root_dir."/tags"
    let s:files_dict = {}
    if filereadable(s:project_file)
        for line in readfile(s:project_file)
            let tokens = split(line, "\t")
            let s:files_dict[tokens[0]]=tokens[1]
        endfor
        for k in keys(s:files_dict)
            call s:ProCheckFile(k)
        endfor
    endif
endfun
command! -nargs=1 ProLoad call s:ProLoadFun(expand("<args>"))

fun! s:ProUnloadFun()
    unlet s:project_file s:root_dir s:tags_file s:files_dict
endfun

fun! s:ProAddFun(fname)
    if !filereadable(a:fname)
        echohl Error
        echom "File does not exist."
        echohl None
        return
    endif
    if !exists("s:files_dict")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    call s:ProCheckFile(a:fname)
endfun
command! -nargs=1 ProAdd call s:ProAddFun(expand("<args>"))

fun! s:ProRemoveFun(fname)
    if !exists("s:files_dict")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    let fname = fnamemodify(a:fname, ":p")
    if has_key(s:files_dict, fname)
        call remove(s:files_dict, fname)
    endif
endfun
command! -nargs=1 ProRemove call s:ProRemoveFun(expand("<args>"))

fun! s:ProListFiles()
    if !exists("s:files_dict")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    let flist = []
    let b = bufnr("%")
    for f in keys(s:files_dict)
        if bufexists(f)
            exec "keepalt silent b ".f
            call add(flist, {"filename": f, "lnum": line("'\"")})
        else
            call add(flist, {"filename": f, "lnum": 1})
        endif
    endfor
    exec "keepalt silent b ".b
    call setqflist(flist)
    cw
endfun
command! ProList call s:ProListFiles()

augroup Pro
    au!
    autocmd BufWritePost * call s:ProCheckFile(expand("<afile>"))
augroup END

