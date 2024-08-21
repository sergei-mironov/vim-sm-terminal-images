let g:local_prop_type_name = 'terminalImagesPopup'

fun! s:Get(name) abort
  return get(b:, a:name, get(g:, a:name))
endfun

fun! s:GetDecorationWidth() abort
  let l:width = &numberwidth + &foldcolumn
  if &signcolumn ==# 'yes' || len(sign_getplaced(bufnr(''), #{group: '*'})[0].signs)
    let l:width += 2
  endif
  return l:width
endfun

fun! s:GetWindowWidth() abort
  return winwidth(0) - s:GetDecorationWidth()
endfun

fun! PopupNextId()
  let b:terminal_images_propid_count =
      \ get(b:, 'terminal_images_propid_count', 0) + 1
  return b:terminal_images_propid_count
endfun

fun! PopupCreateProp(lnum, prop_id)
	call prop_add(a:lnum, 1, #{
		\ length: len(getline(a:lnum)),
		\ type: g:local_prop_type_name,
		\ id: a:prop_id,
		\ })
endfun

fun! PopupCreate(col, row, cols, rows)
  if empty(prop_type_get(g:local_prop_type_name))
    call prop_type_add(g:local_prop_type_name, {})
  endif
	let lnum = a:row
	" let prop_id = PopupNextId()
	let prop_id = 4444
  call PopupCreateProp(lnum, prop_id)
  let background_higroup =
      \ get(b:, 'local_background', 'TerminalImagesBackground')

  " \ line: a:row,
	let popup_id = popup_create('<popup>', #{
    \ col: a:col - strdisplaywidth(getline(lnum)),
		\ pos: 'topleft',
    \ highlight: background_higroup,
    \ fixed: 1,
    \ flip: 0,
    \ posinvert: 0,
    \ minheight: a:rows, minwidth: a:cols,
    \ maxheight: a:rows, maxwidth: a:cols,
    \ zindex: 1000,
		\ textprop: g:local_prop_type_name,
		\ textpropid: prop_id,
		\ })
  return popup_id
endfun

fun! PopupUploadImage(popup_id, filename, cols, rows)
  let props = popup_getpos(a:popup_id)
  echomsg string(props)
  let cols = a:cols
  let rows = a:rows
  let flags = ""
  try
    let text = terminal_images#UploadTerminalImage(a:filename,
      \ {'cols': cols,
      \  'rows': rows,
      \  'flags': flags,
      \ })

    call popup_settext(a:popup_id, text)
  catch
    echomsg "Interrupted:" .v:exception
  endtry
endfun

if !exists('g:terminal_images_command')
  let g:terminal_images_command =
              \ s:path . "/../tupimage/tupimage"
              " \ . " --less-diacritics"
endif

fun! PopupImageDims(filename)
  let win_width = s:GetWindowWidth()
  let maxcols = s:Get('terminal_images_max_columns')
  let maxrows = s:Get('terminal_images_max_rows')
  let right_margin = s:Get('terminal_images_right_margin')
  let maxcols = min([maxcols, &columns, win_width - right_margin])
  let maxrows = min([maxrows, &lines, winheight(0) - 2])
  let maxcols = max([1, maxcols])
  let maxrows = max([1, maxrows])

  let filename_esc = shellescape(a:filename)
  let command = g:terminal_images_command .
              \ " --max-cols " . string(maxcols) .
              \ " --max-rows " . string(maxrows) .
              \ " --quiet " .
              \ " -e /dev/null " .
              \ " --only-dump-dims " .
              \ filename_esc
  silent let dims = split(system(command), " ")
  if v:shell_error != 0
    throw "Non-zero exit code: ".string(v:shell_error)
  endif
  if len(dims) != 2
    throw "Unexpected output: ".string(dims)
  endif
  let cols = str2nr(dims[0])
  let rows = str2nr(dims[1])
  return [cols, rows]
endfun

fun! PopupTest2()
  let filename = "tex/img/parabola.png"
  let [cols, rows] = PopupImageDims(filename)
  let popup_id = PopupCreate(101, line('.'), cols, rows)
  call PopupUploadImage(popup_id, filename, cols, rows)
endfun

