SM Terminal Images
------------------

This project is an experimental rework of the
[vim-terminal-images](https://github.com/sergei-grechanik/vim-terminal-images) Vim plugin by Sergei
Grechanik.

The differences include:
- A simpler one-column image positioning algorithm
- More aggressive preservation of vim resources (properties, popup windows)
- Quiet image uploading to work around problems caused by the `tupimage` statusline
- No built-in CursorHold handler and fewer Vim commands are installed

Usage
-----

The plugin requires a terminal (non-GUI) Vim running in a terminal which supports extentions for
graphic.  We are aware of the following terminals matching this requirement:
- [Kitty Terminal](https://sw.kovidgoyal.net/kitty/)
- [Simple Terminal](https://st.suckless.org/), namely its [Kitty graphics protocol
  branch](https://github.com/sergei-grechanik/st-graphics) (the preferred and the only tested
  terminal)

The plugin provides a function for scanning text for image file names whenever the cursor is idle.
Once detected, the images are displayed in the right column.

The plugin is disabled by default. To enable it, put the following line into your `.vimrc` config:

``` vim
autocmd CursorHold,BufWinEnter * call sm_terminal_images#UpdateVisible()
```

To enable displaying images under cursor by `gi` command, add also the following:

``` vim
nnoremap gi <Esc>:call sm_terminal_images#ShowUnderCursor()<CR>
```

Details
-------

The top-level definitions are:
- `sm_terminal_images#UpdateVisible()` for updating images for links visible on the screen. The
  corresponding vim command is `:SMTIUpdateVisible`.
- `sm_terminal_images#ShowUnderCursor()` for showing image under the cursor


