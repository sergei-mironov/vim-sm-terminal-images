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
if !exists(":TI2UpdateScreen")
  command! -bar -nargs=0 TI2UpdateScreen call terminal_images2#UpdateScreen()
endif
