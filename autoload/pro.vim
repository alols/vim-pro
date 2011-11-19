" File: autoload/pro.vim
" Author: Albin Olsson
" URL: https://github.com/alols/vim-pro
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

fun! pro#CheckFiles(fnames)
    if !exists("{s:PScope}:files_dict")
        return
    endif
    let update_dict = {}   " files to update in tag file ordered by extensions
    let tfile = []         " this variable will hold the tag file if we need to open it
    for fname in a:fnames
        let fname = fnamemodify(fname, ":p")
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
                    continue
                endif
            else
                call remove({s:PScope}:files_dict, fname)
                continue
            endif
        else
            continue
        endif
        let {s:PScope}:files_dict[fname] = ftime
        let ext = fnamemodify(fname, ":e")
        if ext == 'c' || ext == 'h' || ext == 'cpp' || ext == 'py' || ext == 'vim'
            if !has_key(update_dict, ext)
                let update_dict[ext] = [fname]
            else
                call add(update_dict[ext], fname)
            endif
            if filereadable({s:PScope}:tags_file)
                if empty(tfile)
                    let tfile = readfile({s:PScope}:tags_file)
                endif
                let i = match(tfile, fname)
                while i >= 0
                    call remove(tfile, i)
                    let i = match(tfile, fname, i)
                endwhile
            endif
        endif
    endfor
    if !empty(tfile)
        call writefile(tfile, {s:PScope}:tags_file)
    endif
    call pro#ChangeToRootDir()
    for ext in keys(update_dict)
        " TODO ctags command line depends on filetype
        exec "silent !ctags -f ".{s:PScope}:tags_file." -a ".join(update_dict[ext], " ")
    endfor
    call pro#ChangeBackDirs()
    call pro#SaveFun()
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
        call pro#CheckFiles(keys({s:PScope}:files_dict))
    endif
endfun

fun! pro#UnloadFun()
    unlet {s:PScope}:project_file {s:PScope}:root_dir
                \ {s:PScope}:tags_file {s:PScope}:files_dict
endfun

fun! pro#AddFun(...)
    if !exists("{s:PScope}:files_dict")
        echoerr "No project file loaded."
        return
    endif
    let checkfiles = []
    for a in a:000
        for f in split(expand(a), '\n')
            if !filereadable(f)
                echoerr f.": file does not exist."
            else
                let fname = fnamemodify(f, ":p")
                call pro#ChangeToRootDir()
                let fname = fnamemodify(fname, ":.")
                call pro#ChangeBackDirs()
                let {s:PScope}:files_dict[fname]=0
                call add(checkfiles, fname)
            endif
        endfor
    endfor
    call pro#CheckFiles(checkfiles)
endfun

fun! pro#RemoveFun(...)
    if !exists("{s:PScope}:files_dict")
        echoerr "No project file loaded."
        return
    endif
    if filereadable({s:PScope}:tags_file)
        let tfile = readfile({s:PScope}:tags_file)
    endif
    for a in a:000
        for f in split(expand(a), '\n')
            let fname = fnamemodify(f, ":p")
            call pro#ChangeToRootDir()
            let fname = fnamemodify(fname, ":.")
            call pro#ChangeBackDirs()
            if has_key({s:PScope}:files_dict, fname)
                call remove({s:PScope}:files_dict, fname)
            endif
            if exists("tfile")
                let i = match(tfile, fname)
                while i >= 0
                    call remove(tfile, i)
                    let i = match(tfile, fname, i)
                endwhile
            endif
        endfor
    endfor
    if exists("tfile")
        call writefile(tfile, {s:PScope}:tags_file)
    endif
    call pro#SaveFun()
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

