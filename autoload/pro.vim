" File: autoload/pro.vim
" Maintainer: Albin Olsson
"

" project is local to tab page, change this
" to 'g' to make project global
let s:PScope='t'

fun! pro#ChangeToRootDir()
    let s:curdir = getcwd()
    silent! lcd -
    let s:prevdir = getcwd()
    exec "lcd ".{s:PScope}:root_dir
endfun

fun! pro#ChangeBackDirs()
    exec "lcd ".s:prevdir
    exec "lcd ".s:curdir
    unlet s:prevdir
    unlet s:curdir
endfun

fun! pro#GrepFun(grepcommand)
    if !exists("{s:PScope}:files_dict")
        echoerr "No project file loaded."
    elseif empty({s:PScope}:files_dict)
        echoerr "No files in project."
    else
        call pro#ChangeToRootDir()
        let grepcommand = "vimgrep ".a:grepcommand.' '.join(keys({s:PScope}:files_dict), ' ')
        try
            exec grepcommand
            exec "2match Search ".substitute(a:grepcommand, "\\(^/.*/\\).*$", "\\1", "")
        catch /E480/
            echom "Pattern not found in project"
        endtry
        call pro#ChangeBackDirs()
    endif
endfun

fun! pro#TagUpdate(fname)
    if exists("{s:PScope}:tags_file")
        call pro#ChangeToRootDir()
        let ftype = fnamemodify(a:fname, ":e")
        " TODO ctags command line depends on filetype
        if ftype == 'c' || ftype == 'h' || ftype == 'cpp' || ftype == 'py' || ftype == 'vim'
            if filereadable({s:PScope}:tags_file)
                let tfile = readfile({s:PScope}:tags_file)
                let i = match(tfile, a:fname)
                while i >= 0
                    call remove(tfile, i)
                    let i = match(tfile, a:fname, i)
                endwhile
                call writefile(tfile, {s:PScope}:tags_file)
            endif
            exec "silent !ctags -f ".{s:PScope}:tags_file." -a ".a:fname
        endif
        call pro#ChangeBackDirs()
    endif
endfun

fun! pro#CheckFile(fname, add)
    if exists("{s:PScope}:files_dict")
        let fname = fnamemodify(a:fname, ":p")
        call pro#ChangeToRootDir()
        let fname = fnamemodify(fname, ":.")
        let readable = filereadable(fname)
        let ftime = getftime(fname)
        call pro#ChangeBackDirs()
        if has_key({s:PScope}:files_dict, fname)
            if readable
                if {s:PScope}:files_dict[fname] == ftime
                    " fname is already part of project
                    " and is unmodified
                    return
                endif
            else
                call remove({s:PScope}:files_dict, fname)
                return
            endif
        elseif !readable || !a:add
            return
        endif
        let {s:PScope}:files_dict[fname] = ftime
        call pro#TagUpdate(fname)
        call pro#SaveFun()
    endif
endfun

fun! pro#SaveFun()
    if exists("{s:PScope}:project_file")
        let lines = []
        for i in items({s:PScope}:files_dict)
            call add(lines, join(i, "\t"))
        endfor
        call writefile(lines, {s:PScope}:project_file)
    endif
endfun

fun! pro#LoadFun(fname)
    let {s:PScope}:project_file = fnamemodify(a:fname, ":p")
    let {s:PScope}:root_dir = fnamemodify({s:PScope}:project_file, ":p:h")
    let {s:PScope}:tags_file = {s:PScope}:project_file.".tags"
    let {s:PScope}:files_dict = {}
    if filereadable({s:PScope}:project_file)
        for line in readfile({s:PScope}:project_file)
            let tokens = split(line, "\t")
            let {s:PScope}:files_dict[tokens[0]]=tokens[1]
        endfor
        for k in keys({s:PScope}:files_dict)
            call pro#CheckFile(k, 0)
        endfor
    endif
endfun

fun! pro#UnloadFun()
    unlet {s:PScope}:project_file {s:PScope}:root_dir
                \ {s:PScope}:tags_file {s:PScope}:files_dict
endfun

fun! pro#AddFun(fname)
    if !filereadable(a:fname)
        echoerr a:fname.": file does not exist."
    else
        call pro#CheckFile(a:fname, 1)
    endif
endfun

fun! pro#RemoveFun(fname)
    call pro#ChangeToRootDir()
    let fname = fnamemodify(a:fname, ":.")
    call pro#ChangeBackDirs()
    if has_key({s:PScope}:files_dict, fname)
        call remove({s:PScope}:files_dict, fname)
    endif
endfun

fun! pro#ExpandFiles(fun, ...)
    if !exists("{s:PScope}:files_dict")
        echoerr "No project file loaded."
        return
    endif
    for a in a:000
        for f in split(expand(a), '\n')
            silent! call a:fun(f)
        endfor
    endfor
endfun

fun! pro#ListFiles()
    if !exists("{s:PScope}:files_dict")
        echoerr "No project file loaded."
        return
    endif
    let flist = []
    let b = bufnr("%")
    call pro#ChangeToRootDir()
    for f in keys({s:PScope}:files_dict)
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
    call pro#ChangeBackDirs()
endfun

fun! pro#DoFun(command)
    if !exists("{s:PScope}:files_dict")
        echoerr "No project file loaded."
        return
    endif
    call pro#ChangeToRootDir()
    for f in keys({s:PScope}:files_dict)
        exec a:command.' '.f
    endfor
    call pro#ChangeBackDirs()
endfun

fun! pro#PComplete(Lead, Line, Pos)
    echom a:Lead
    if !exists("{s:PScope}:files_dict")
        return []
    else
        let rval = []
        for f in keys({s:PScope}:files_dict)
            if -1 != stridx(f, a:Lead)
                call pro#ChangeToRootDir()
                let f = fnamemodify(f, ":p")
                call pro#ChangeBackDirs()
                let f = fnamemodify(f, ":.")
                call add(rval, f)
            endif
        endfor
        return rval
    endif
endfun
