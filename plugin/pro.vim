fun! s:GrepFun(grepcommand)
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
command! -nargs=1 Pgrep call s:GrepFun(<q-args>)

fun! s:TagUpdate(fname)
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

fun! s:CheckFile(fname)
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
        call s:TagUpdate(fname)
        call s:SaveFun()
    endif
endfun

fun! s:SaveFun()
    if exists("s:project_file")
        let lines = []
        for i in items(s:files_dict)
            call add(lines, join(i, "\t"))
        endfor
        call writefile(lines, s:project_file)
    endif
endfun

fun! s:LoadFun(fname)
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
            call s:CheckFile(k)
        endfor
    endif
endfun
command! -nargs=1 -complete=file Pload call s:LoadFun(<q-args>)

fun! s:UnloadFun()
    unlet s:project_file s:root_dir s:tags_file s:files_dict
endfun
command! Punload call s:UnloadFun()

fun! s:AddFun(fname)
    if !filereadable(a:fname)
        echohl Error
        echom a:fname.": file does not exist."
        echohl None
    else
        call s:CheckFile(a:fname)
    endif
endfun

fun! s:RemoveFun(fname)
    let fname = fnamemodify(a:fname, ":p")
    if has_key(s:files_dict, fname)
        call remove(s:files_dict, fname)
    endif
endfun

fun! s:ExpandFiles(fun, ...)
    if !exists("s:files_dict")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    for a in a:000
        for f in split(expand(a), '\n')
            exec "call ".a:fun."(\"".f."\")"
        endfor
    endfor
endfun
command! -nargs=+ -complete=file Padd call s:ExpandFiles("s:AddFun", <f-args>)
command! -nargs=+ -complete=file Prm call s:ExpandFiles("s:RemoveFun", <f-args>)

fun! s:ListFiles()
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
    echom "Project files loaded into quickfix list."
endfun
command! Pls call s:ListFiles()

fun! s:DoFun(command)
    if !exists("s:files_dict")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    for f in keys(s:files_dict)
        exec a:command.' '.f
    endfor
endfun
command! -nargs=1 Pdo call s:DoFun(<q-args>)

augroup Pro
    au!
    autocmd BufWritePost * call s:CheckFile(expand("<afile>"))
augroup END
