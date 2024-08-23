if !exists('g:terminal_images2_prop_type_name')
  let g:terminal_images2_prop_type_name = 'TerminalImages2Popup'
endif
if !exists('g:terminal_images2_command')
  let g:terminal_images2_command = "tupimage"
endif
if !exists('g:terminal_images2_right_margin')
  let g:terminal_images2_right_margin = 1
endif
if !exists('g:terminal_images2_left_margin')
  let g:terminal_images2_left_margin = 100
endif
if !exists('g:terminal_images2_max_rows')
  let g:terminal_images2_max_rows = 25
endif
if !exists('g:terminal_images2_max_columns')
  let g:terminal_images2_max_columns = 80
endif
if !exists('g:terminal_images2_regex')
  let g:terminal_images2_regex = '\c\([a-z0-9_+=/$%-]\+\.\(png\|jpe\?g\|gif\)\)'
endif
if !exists('g:terminal_images2_subdir_glob')
  let g:terminal_images2_subdir_glob = '*'
endif

" Highlight group used for floating window background. The background can also
" be controlled in per-buffer manner by setting `b:terminal_images_background`.
if !hlexists('TerminalImages2Background')
  highlight link TerminalImages2Background Pmenu
endif

" Highlighting groups TerminalImages2ID1..TerminalImages2ID255 are used for the
" corresponding image IDs.
for i in range(1, 255)
  let higroup_name = "TerminalImages2ID" . string(i)
  execute "hi " . higroup_name . " ctermfg=" . string(i)
  let prop_name = "TerminalImages2ID" . string(i)
  if !empty(prop_type_get(prop_name))
    call prop_type_delete(prop_name)
  endif
  call prop_type_add(prop_name, {'highlight': higroup_name})
endfor

if !exists(":TI2UpdateScreen")
  command! -bar -nargs=0 TI2UpdateScreen call terminal_images2#UpdateScreen()
endif
