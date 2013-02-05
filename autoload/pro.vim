" File: autoload/pro.vim
" Author: Albin Olsson
" URL: https://github.com/alols/vim-pro
"

"Helper functions needed so that paths can be relative
fun! pro#ChangeToRootDir()
    let s:curdir = getcwd()
    silent! lcd -
    let s:prevdir = getcwd()
    exec "lcd ".s:root_dir
endfun

fun! pro#ChangeBackDirs()
    exec "lcd ".s:prevdir
    exec "lcd ".s:curdir
    unlet s:prevdir
    unlet s:curdir
endfun

fun! pro#HereToProject(Fname)
    let fname = fnamemodify(a:Fname, ":p")
    call pro#ChangeToRootDir()
    let fname = fnamemodify(fname, ":.")
    call pro#ChangeBackDirs()
    return fname
endfun

fun! pro#ProjectToHere(Fname)
    call pro#ChangeToRootDir()
    let fname = fnamemodify(a:Fname, ":p")
    call pro#ChangeBackDirs()
    let fname = fnamemodify(fname, ":.")
    return fname
endfun

fun! pro#Grep(grepcommand)
    if !exists("s:files_dict")
        echoerr "No project file loaded."
    elseif empty(s:files_dict)
        echoerr "No files in project."
    else
        call pro#ChangeToRootDir()
        let grepcommand = "vimgrep ".a:grepcommand.' '.join(keys(s:files_dict), ' ')
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
    if !exists("s:files_dict")
        return
    endif
    let update_dict = {}   " files to update in tag file ordered by extensions
    let tfile = []         " this variable will hold the tag file if we need to open it
    for fname in a:fnames
        let fname = pro#HereToProject(fname)
        call pro#ChangeToRootDir()
        let readable = filereadable(fname)
        let ftime = getftime(fname)
        call pro#ChangeBackDirs()
        if has_key(s:files_dict, fname)
            if readable
                if s:files_dict[fname] == ftime
                    " file is already part of project
                    " and is unmodified
                    continue
                endif
            else
                " file does not seem to exist, ignore it
                continue
            endif
        else
            " file is not part of project, skip it
            continue
        endif
        " save timestamp
        let s:files_dict[fname] = ftime
        let ext = fnamemodify(fname, ":e")
        if !has_key(update_dict, ext)
            let update_dict[ext] = [fname]
        else
            call add(update_dict[ext], fname)
        endif
        if filereadable(s:tags_file)
            if empty(tfile)
                let tfile = readfile(s:tags_file)
            endif
            let i = match(tfile, fname)
            while i >= 0
                call remove(tfile, i)
                let i = match(tfile, fname, i)
            endwhile
        endif
    endfor
    if !empty(tfile)
        call writefile(tfile, s:tags_file)
    endif
    call pro#ChangeToRootDir()
    for ext in keys(update_dict)
        let ctags_cmd = "silent !ctags -f ".s:tags_file." -a"
        if has_key(g:PTagExt, ext)
            let ctags_cmd = ctags_cmd." ".g:PTagExt[ext]
        endif
        " Need to do this as a loop because MS Windows has a
        " ridiculous cmd line max length.
        let cmdline = ctags_cmd
        for f in update_dict[ext]
            if strlen(cmdline) + strlen(f) + 1 > 2047
                exec cmdline
                let cmdline = ctags_cmd
            endif
            let cmdline = cmdline." ".f
        endfor
        exec cmdline
    endfor
    call pro#ChangeBackDirs()
    call pro#Save()
endfun

fun! pro#Save()
    if exists("g:PProjectFile")
        let lines = []
        call add(lines, "!_VIMPRO_FILE_VERSION\t0\t1")
        if exists("s:settings")
            call add(lines, "!_VIMPRO_SETTINGS\t".s:settings)
        endif
        for i in items(s:files_dict)
            call add(lines, join(i, "\t"))
        endfor
        call writefile(lines, g:PProjectFile)
    endif
endfun

fun! pro#Create(fname)
    if filereadable(a:fname)
        echoerr "A file with that name already exists."
    else
        call writefile(["!_VIMPRO_FILE_VERSION\t0\t1"], a:fname)
        call pro#Load(a:fname)
    endif
endfun

fun! pro#Load(fname)
    if !filereadable(a:fname)
        echoerr "No such file."
    else
        let g:PProjectFile = fnamemodify(a:fname, ":p")
        let s:root_dir = fnamemodify(g:PProjectFile, ":p:h")
        let s:tags_file = g:PProjectFile.".tags"
        let s:files_dict = {}
        try
            let file = readfile(g:PProjectFile)
            let file_ver = split(file[0], "\t")
            if file_ver[0] != "!_VIMPRO_FILE_VERSION"
                throw "Not a project file."
            elseif file_ver[1] > 0
                throw "You need to update vimpro-plugin to open this project."
            endif
            for line in file
                let tokens = split(line, "\t")
                if 0 != stridx(tokens[0], "!_VIMPRO_")
                    let s:files_dict[tokens[0]]=tokens[1]
                elseif tokens[0] == "!_VIMPRO_SETTINGS"
                    let s:settings = tokens[1]
                endif
            endfor
            call pro#CheckFiles(keys(s:files_dict))
        catch
            unlet g:PProjectFile s:root_dir
                        \ s:tags_file s:files_dict
            echoerr "Error loading project file. ".v:exception
            return
        endtry
        if -1 == stridx(&tags, s:tags_file)
            exec "set tags=".s:tags_file.",".&tags
        endif
    endif
endfun

fun! pro#Unload()
    let beg = stridx(&tags, s:tags_file)
    if beg != -1
        let end = 1+stridx(&tags, ",", beg)
        exec "set tags=".strpart(&tags, 0, beg).strpart(&tags, end)
    endif
    unlet g:PProjectFile s:root_dir
                \ s:tags_file s:files_dict
endfun

fun! pro#Add(...)
    if !exists("s:files_dict")
        echoerr "No project file loaded."
        return
    endif
    let checkfiles = []
    for a in a:000
        for f in split(expand(a), '\n')
            if !filereadable(f)
                echoerr f.": file does not exist."
            else
                let fname = pro#HereToProject(f)
                let s:files_dict[fname]=0
                call add(checkfiles, fname)
            endif
        endfor
    endfor
    call pro#CheckFiles(checkfiles)
endfun

fun! pro#Remove(...)
    if !exists("s:files_dict")
        echoerr "No project file loaded."
        return
    endif
    if filereadable(s:tags_file)
        let tfile = readfile(s:tags_file)
    endif
    for a in a:000
        for f in split(expand(a), '\n')
            let fname = pro#HereToProject(f)
            if has_key(s:files_dict, fname)
                call remove(s:files_dict, fname)
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
        call writefile(tfile, s:tags_file)
    endif
    call pro#Save()
endfun

fun! pro#PComplete(Lead, Line, Pos)
    echom a:Lead
    if !exists("s:files_dict")
        return []
    else
        let rval = []
        for f in keys(s:files_dict)
            let mf = fnamemodify(f, ":t")
            if 0 == stridx(mf, a:Lead)
                let f = pro#ProjectToHere(f)
                call add(rval, f)
            endif
        endfor
        if empty(rval)
            " no filename begins with a:Lead, do a more
            " generous search to find matches
            for f in keys(s:files_dict)
                if -1 != stridx(f, a:Lead)
                    let f = pro#ProjectToHere(f)
                    call add(rval, f)
                endif
            endfor
        endif
        return rval
    endif
endfun

fun! pro#Set(Settings)
    if !exists("s:files_dict")
        echoerr "No project file loaded."
        return
    endif
    if empty(a:Settings)
        if exists("s:settings")
            echo s:settings
        endif
    else
        let s:settings = a:Settings
        bufdo if has_key(s:files_dict, pro#HereToProject(expand('%'))) |
                    \ exec "setlocal ".s:settings | endif
        call pro#Save()
    endif
endfun

fun! pro#CheckSettings(Fname)
    if !exists("s:settings")
        return
    endif
    let fname = pro#HereToProject(a:Fname)
    if has_key(s:files_dict, fname)
        exec "setlocal ".s:settings
    endif
endfun

fun! List()
    if !exists("s:files_dict")
        echoerr "No project file loaded."
    else
        let lines = []
        for f in keys(s:files_dict)
            let f = pro#ProjectToHere(f)
            call add(lines, {'filename' : f, 'lnum' : 1})
        endfor
        call setqflist(lines)
    endif
endfun
