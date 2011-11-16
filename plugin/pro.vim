" File: pro.vim
" Maintainer: Albin Olsson


fun! s:ChangeToRootDir()
    let s:curdir = getcwd()
    silent! lcd -
    let s:prevdir = getcwd()
    exec "lcd ".s:root_dir
endfun

fun! s:ChangeBackDirs()
    exec "lcd ".s:prevdir
    exec "lcd ".s:curdir
    unlet s:prevdir
    unlet s:curdir
endfun

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
        call s:ChangeToRootDir()
        let grepcommand = "vimgrep ".a:grepcommand.' '.join(keys(s:files_dict), ' ')
        try
            exec grepcommand
            exec "2match Search ".substitute(a:grepcommand, "\\(^/.*/\\).*$", "\\1", "")
        catch /E480/
            echom "Pattern not found in project"
        endtry
        call s:ChangeBackDirs()
    endif
endfun
command! -nargs=1 Pgrep call s:GrepFun(<q-args>)

fun! s:TagUpdate(fname)
    if exists("s:tags_file")
        let ftype = fnamemodify(a:fname, ":e")
        " TODO ctags command line depends on filetype
        if ftype == 'c' || ftype == 'h' || ftype == 'cpp' || ftype == 'py' || ftype == 'vim'
            if filereadable(s:tags_file)
                let tfile = readfile(s:tags_file)
                let i = match(tfile, a:fname)
                while i >= 0
                    call remove(tfile, i)
                    let i = match(tfile, a:fname, i)
                endwhile
                call writefile(tfile, s:tags_file)
            endif
            exec "silent !ctags -f ".s:tags_file." -a ".a:fname
        endif
    endif
endfun

fun! s:CheckFile(fname)
    if exists("s:files_dict")
        call s:ChangeToRootDir()
        let fname = fnamemodify(a:fname, ":.")
        let readable = filereadable(fname)
        let ftime = getftime(fname)
        if has_key(s:files_dict, fname)
            if readable
                if s:files_dict[fname] == ftime
                    " fname is already part of project
                    " and is unmodified
                    call s:ChangeBackDirs()
                    return
                endif
            else
                call remove(s:files_dict, fname)
                call s:ChangeBackDirs()
                return
            endif
        elseif !readable
            call s:ChangeBackDirs()
            return
        endif
        let s:files_dict[fname] = ftime
        call s:TagUpdate(fname)
        call s:SaveFun()
        call s:ChangeBackDirs()
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
    let s:tags_file = s:project_file.".tags"
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
    call s:ChangeToRootDir()
    let fname = fnamemodify(a:fname, ":.")
    if has_key(s:files_dict, fname)
        call remove(s:files_dict, fname)
    endif
    call s:ChangeBackDirs()
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
command! -nargs=+ -complete=customlist,s:PComplete Prm call s:ExpandFiles("s:RemoveFun", <f-args>)

fun! s:ListFiles()
    if !exists("s:files_dict")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    let flist = []
    let b = bufnr("%")
    call s:ChangeToRootDir()
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
    call s:ChangeBackDirs()
endfun
command! Pls call s:ListFiles()

fun! s:DoFun(command)
    if !exists("s:files_dict")
        echohl Error
        echom "No project file loaded."
        echohl None
        return
    endif
    call s:ChangeToRootDir()
    for f in keys(s:files_dict)
        exec a:command.' '.f
    endfor
    call s:ChangeBackDirs()
endfun
command! -nargs=1 Pdo call s:DoFun(<q-args>)

fun! s:PComplete(Lead, Line, Pos)
    echom a:Lead
    if !exists("s:files_dict")
        return []
    else
        let rval = []
        for f in keys(s:files_dict)
            if -1 != stridx(f, a:Lead)
                call add(rval, f)
            endif
        endfor
        return rval
    endif
endfun
command! -nargs=+ -complete=customlist,s:PComplete Pe e <args>

augroup Pro
    au!
    autocmd BufWritePost * call s:CheckFile(expand("<afile>"))
augroup END
