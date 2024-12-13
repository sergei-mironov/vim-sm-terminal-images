if !exists('g:sm_terminal_images_prop_type_name')
  let g:sm_terminal_images_prop_type_name = 'SMTerminalImagesPopup'
endif
if !exists('g:sm_terminal_images_command')
  let g:sm_terminal_images_command = "tupimage"
endif
if !exists('g:sm_terminal_images_right_margin')
  let g:sm_terminal_images_right_margin = 1
endif
if !exists('g:sm_terminal_images_left_margin')
  let g:sm_terminal_images_left_margin = 100
endif
if !exists('g:sm_terminal_images_max_rows')
  let g:sm_terminal_images_max_rows = 25
endif
if !exists('g:sm_terminal_images_max_columns')
  let g:sm_terminal_images_max_columns = 80
endif
if !exists('g:sm_terminal_images_regex')
  let g:sm_terminal_images_regex = '\c\([a-z0-9_+=/$%-]\+\.\(png\|jpe\?g\|gif\)\)'
endif
if !exists('g:sm_terminal_images_subdir_glob')
  let g:sm_terminal_images_subdir_glob = '*'
endif

" Highlight group used for floating window background. The background can also
" be controlled in per-buffer manner by setting `b:terminal_images_background`.
if !hlexists('SMTerminalImagesBackground')
  highlight link SMTerminalImagesBackground Pmenu
endif

" Highlighting groups SMTerminalImagesID1..SMTerminalImagesID255 are used for the
" corresponding image IDs.
for i in range(1, 255)
  let higroup_name = "SMTerminalImagesID" . string(i)
  execute "hi " . higroup_name . " ctermfg=" . string(i)
  let prop_name = "SMTerminalImagesID" . string(i)
  if !empty(prop_type_get(prop_name))
    call prop_type_delete(prop_name)
  endif
  call prop_type_add(prop_name, {'highlight': higroup_name})
endfor

if !exists(":SMTIUpdateVisible")
  command! -bar -nargs=0 SMTIUpdateVisible call sm_terminal_images#UpdateVisible()
endif
