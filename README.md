Terinal images 2
----------------

Experimental rework of
[vim-terminal-images](https://github.com/sergei-grechanik/vim-terminal-images) by Sergei Grechanik.

The differences include:
- A simpler one-column image positioning algorithm
- More aggressive preservation of vim resources (properties, popup windows)
- Quiet image uploading to work around problems caused by the `tupimage` statusline
- No built-in CursorHold handler and fewer Vim commands are installed

Usage
-----

The top-level definitions are:
- `terminal_images2#UpdateVisible()` for updating images for links visible on the screen. The
  corresponding vim command is `:TI2UpdateVisible`.
- `terminal_images2#ShowUnderCursor()` for showing image under the cursor

Hints
-----

* It makes sense to perform updates on the cursor hold event:
  ``` vim
  autocmd CursorHold,BufWinEnter * call terminal_images2#UpdateVisible()
  ```


