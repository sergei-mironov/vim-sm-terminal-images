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

This plugin requires the following software:

1. [tupiamge](https://github.com/sergei-grechanik/tupimage) terminal graphics tool by Sergei
   Grechanik.

2. A terminal supporting the Kitty graphics protocol. We are aware of the following terminals
   matching this requirement:
   - [Kitty Terminal](https://sw.kovidgoyal.net/kitty/) itself.
   - [Simple Terminal](https://st.suckless.org/), namely its [Kitty graphics protocol
     branch](https://github.com/sergei-grechanik/st-graphics) (the preferred and the only tested
     terminal).
   - Refer to the `tupimage` page for more possible options.

The plugin provides a function for scanning text for image file names whenever the cursor is idle.
Once detected, the images are displayed in one column near the right border of the screen.

The plugin only publishes a few top-level functions. To use them, put the following line into your
`.vimrc` config:

``` vim
autocmd CursorHold,BufWinEnter * call sm_terminal_images#UpdateVisible()
```

To enable displaying images under cursor by `gi` command, add also the following:

``` vim
nnoremap gi <Esc>:call sm_terminal_images#ShowUnderCursor()<CR>
```

