let g:terminal_images_auto = 0
let g:sm_terminal_images_background = 0

autocmd CursorHold,BufWinEnter * call sm_terminal_images#UpdateVisible()
nnoremap gi <Esc>:call sm_terminal_images#ShowUnderCursor()<CR>
" Do not search for images very carefully
let g:sm_terminal_images_subdir_glob = ''
" Display svg images
let g:sm_terminal_images_regex = '\c\([a-z0-9_+=/$%-]\+\.\(svg\|png\|jpe\?g\|gif\)\)'
