" File: autoload/pro.vim
" Author: Albin Olsson
" URL: https://github.com/alols/vim-pro
"

" project scope is global, change this to 't'
" to make it local to tab page
" (EXPERIMENTAL, do not use!!!)
let s:PScope='g'

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
            " will highlight the matches
            " exec "2match Search ".substitute(a:grepcommand, "\\(^/.*/\\).*$", "\\1", "")
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
        " get the filename relative to project root
        let fname = fnamemodify(fname, ":.")
        " check if the file exists
        let readable = filereadable(fname)
        " check when it was modified
        let ftime = getftime(fname)
        call pro#ChangeBackDirs()
        if has_key({s:PScope}:files_dict, fname)
            if readable
                if {s:PScope}:files_dict[fname] == ftime
                    " file is already part of project
                    " and is unmodified
                    continue
                endif
            else
                " file does not exist, remove it from project
                call remove({s:PScope}:files_dict, fname)
                " TODO remove tags!!!
                continue
            endif
        else
            " file is not part of project, skip it
            continue
        endif
        " save timestamp
        let {s:PScope}:files_dict[fname] = ftime
        let ext = fnamemodify(fname, ":e")
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
    endfor
    if !empty(tfile)
        call writefile(tfile, {s:PScope}:tags_file)
    endif
    call pro#ChangeToRootDir()
    for ext in keys(update_dict)
        " TODO ctags command line depends on filetype
        if has_key(g:PTagExt, ext)
            exec "silent !ctags -f ".{s:PScope}:tags_file." -a "g:PTagExt[ext]." ".join(update_dict[ext], " ")
        else
            exec "silent !ctags -f ".{s:PScope}:tags_file." -a ".join(update_dict[ext], " ")
        endif
    endfor
    call pro#ChangeBackDirs()
    call pro#SaveFun()
endfun

fun! pro#SaveFun()
    if exists("{s:PScope}:project_file")
        let lines = []
        call add(lines, "!_VIMPRO_FILE_VERSION\t0\t1")
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
        try
            let file = readfile({s:PScope}:project_file)
            let file_ver = split(file[0], "\t")
            if file_ver[0] != "!_VIMPRO_FILE_VERSION"
                throw "Not a project file."
            elseif file_ver[1] > 0
                throw "You need to update vimpro-plugin to open this project."
            endif
            for line in file
                let tokens = split(line, "\t")
                if 0 != stridx(tokens[0], "!_VIMPRO_")
                    let {s:PScope}:files_dict[tokens[0]]=tokens[1]
                endif
            endfor
            call pro#CheckFiles(keys({s:PScope}:files_dict))
        catch
            unlet {s:PScope}:project_file {s:PScope}:root_dir
                        \ {s:PScope}:tags_file {s:PScope}:files_dict
            echoerr "Error loading project file. ".v:exception
            return
        endtry
    endif
    if -1 == stridx(&tags, {s:PScope}:tags_file)
        exec "set tags=".{s:PScope}:tags_file.",".&tags
    endif
endfun

fun! pro#UnloadFun()
    let beg = stridx(&tags, {s:PScope}:tags_file)
    if beg != -1
        let end = 1+stridx(&tags, ",", beg)
        exec "set tags=".strpart(&tags, 0, beg).strpart(&tags, end)
    endif
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

fun! pro#PComplete(Lead, Line, Pos)
    echom a:Lead
    if !exists("{s:PScope}:files_dict")
        return []
    else
        let rval = []
        for f in keys({s:PScope}:files_dict)
            let mf = fnamemodify(f, ":t")
            if 0 == stridx(mf, a:Lead)
                call pro#ChangeToRootDir()
                let f = fnamemodify(f, ":p")
                call pro#ChangeBackDirs()
                let f = fnamemodify(f, ":.")
                call add(rval, f)
            endif
        endfor
        if empty(rval)
            " no filename begins with a:Lead, do a more
            " generous search to find matches
            for f in keys({s:PScope}:files_dict)
                if -1 != stridx(f, a:Lead)
                    call pro#ChangeToRootDir()
                    let f = fnamemodify(f, ":p")
                    call pro#ChangeBackDirs()
                    let f = fnamemodify(f, ":.")
                    call add(rval, f)
                endif
            endfor
        endif
        return rval
    endif
endfun

