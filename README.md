vimpro
======

Vim plug-in for easy navigation of software projects.

Author: Albin Olsson

For details, please refer to the [documentation](https://github.com/alols/vim-pro/blob/master/doc/vimpro.txt).

Design Goals
------------

The purpose of this plug-in is NOT to add any new kinds of windows to Vim
and it never will be. The purpose is rather to add the concept of
a software project and integrate it as tightly as possible with the way
Vim already works. It automates tag generation and adds a few new
commands. The rest is up to the user.

Sample Use
----------

1.  In the root of your project directory tree, create a new project file

        :Pcreate vimproject

2.  Add your files to the project, for a C project it might be done like
   this:

        :Padd **/*.c **/*.h

    To add the current file:

        :Padd %

    To automatically add new C files when they are saved:

        :autocmd BufWritePost *.c Padd %

3.  vimpro will automatically generate a tags file and keep it updated. It
    will add the tags file to your `tags` option, but it will not remove
    anything already present. This way you can still use multiple tag
    files.

4.  The `:Pe` command works just like :e, but it gives you a lot better
    tab-completion. The completion is very similar to `:b`, but it is not
    based on open buffers but on the files in the project.

5.  The `:Pgrep` command works just like `:vimgrep`, but it takes no filenames
    argument, instead the grep is performed in all project files.

6.  The next time you start Vim you have to load your project.

        :Pload {file}

    If you use sessions, the project will be part of your session as long as
    it is loaded when you run `mksession`. Loading the session will
    automatically load the project.
