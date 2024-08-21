let g:terminal_images2_prop_type_name = 'terminalImagesPopup'
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

fun! PropNextId()
  let b:terminal_images2_propid_count =
        \ get(b:, 'terminal_images2_propid_count', 0) + 1
  return b:terminal_images2_propid_count
endfun


fun! PropGetIdByUrl(url)
  return str2nr(sha256(a:url)[:6],16)
endfun


" fun! PropCreateOrGetId(url)
"   let b:terminal_images2_url2prop = get(b:, 'terminal_images2_url2prop', {})
"   if has_key(b:terminal_images2_url2prop, a:url)
"     let prop_id = b:terminal_images2_url2prop[a:url]
"   else
"     let prop_id = PropNextId()
"     let b:terminal_images2_url2prop[a:url] = prop_id
"   endif
"   return prop_id
" endfun

let b:terminal_images2_prop2line = {}

fun! PropCreate(lnum, url)
  if empty(prop_type_get(g:terminal_images2_prop_type_name))
    call prop_type_add(g:terminal_images2_prop_type_name, {})
  endif
	let prop_id = PropGetIdByUrl(a:url)
	" let prop_id = 4444
	call prop_add(a:lnum, 1, #{
        \ length: 0,
        \ type: g:terminal_images2_prop_type_name,
        \ id: prop_id,
        \ })
  echow "Created prop_id ".string(prop_id). " at lnum ".string(a:lnum)

  let prop = #{id:prop_id, lnum:a:lnum}
  " let b:terminal_images2_prop2line[prop_id] = a:lnum
  return prop
endfun


fun! PropGetOrCreate(lnum, url)
  let lnum = a:lnum
  if lnum > line('$')
    let lnum=line('$')
  endif
	let prop_id = PropGetIdByUrl(a:url)
  call prop_remove(#{id:prop_id})
  let props = prop_list(lnum, #{ids: [prop_id]})
  if len(props)==0
    return PropCreate(lnum, a:url)
  elseif len(props)==1
    echow "Found prop_id ".string(prop_id). " at lnum ".string(lnum)
    return #{id:prop_id, lnum:lnum}
  else
    throw "Too many props in line".lnum
  endif
endfun

fun! PopupCreate(filename, prop, col, row, cols, rows)
  let background_higroup =
        \ get(b:, 'terminal_images2_background', 'TerminalImagesBackground')

	let popup_id = popup_create('<popup>', #{
        \ line: a:row-a:prop.lnum-1,
        \ col: a:col,
        \ pos: 'topleft',
        \ close: 'click',
        \ highlight: background_higroup,
        \ fixed: 1,
        \ flip: 0,
        \ posinvert: 0,
        \ minheight: a:rows, minwidth: a:cols,
        \ maxheight: a:rows, maxwidth: a:cols,
        \ zindex: 1000,
        \ textprop: g:terminal_images2_prop_type_name,
        \ textpropid: a:prop.id,
        \ })
  echow "Created popup_id ". string(popup_id). " for prop_id ".string(a:prop.id)
  call PopupUploadImage(popup_id, a:filename, a:cols, a:rows)
  return popup_id
endfun


fun! PopupOccupiedLines1(popup_id, excluded) " [int,int]|[]
  let sline = line('w0')
  let pos = popup_getpos(a:popup_id)
  let opt = popup_getoptions(a:popup_id)
  if count(a:excluded, get(opt, "textpropid", -1))==0 &&
   \ get(opt, "textprop", "") == g:terminal_images2_prop_type_name &&
   \ pos.visible
    return [sline+pos.line-1, sline+pos.line-1+opt.maxheight]
  else
    return []
  endif
endfun

fun! s:Compare(a,b)
  if a:a[0]!=a:b[0]
    return a:a[0]>a:b[0]
  else
    return a:a[1]>a:b[1]
  endif
endfun

fun! PopupOccupiedLines(excluded) " [[int,int]]
  let ret = []
  for popup_id in popup_list()
    let occupied = PopupOccupiedLines1(popup_id, a:excluded)
    if len(occupied)>0
      call add(ret, occupied)
    endif
  endfor
  return sort(ret, "s:Compare")
endfun

fun! PopupGetOrCreate(filename, prop, col, row, cols, rows)
  for popup_id in popup_list()
    let opt = popup_getoptions(popup_id)
    echow "Checking popup_id".string(popup_id).": ".string(opt)
    if has_key(opt, "textpropid") && opt.textpropid == a:prop.id
      if opt.maxwidth==a:cols && opt.maxheight==a:rows
        echow "Found popup_id ". string(popup_id). " for prop_id ".string(a:prop.id)
        call popup_move(popup_id, #{line:a:row-a:prop.lnum-1})
        let pos = popup_getpos(popup_id)
        if !pos.visible
          call popup_show(popup_id)
        endif
        return popup_id
      else
        call popup_close(popup_id)
        echow "Re-creating popup for prop_id ".string(a:prop.id)
        break
      endif
    endif
  endfor
  let popup_id = PopupCreate(a:filename, a:prop, a:col, a:row, a:cols, a:rows)
  return popup_id
endfun

fun! PopupUploadImage(popup_id, filename, cols, rows)
  let props = popup_getpos(a:popup_id)
  echow string(props)
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

fun! PopupImageDims(filename, maxcols, maxrows)
  let win_width = s:GetWindowWidth()
  let maxcols = s:Get('terminal_images2_max_columns')
  let maxrows = s:Get('terminal_images2_max_rows')
  let right_margin = s:Get('terminal_images2_right_margin')
  let left_margin = s:Get('terminal_images2_left_margin')
  let maxcols = min([maxcols, &columns, win_width - right_margin - left_margin])
  let maxrows = min([maxrows, &lines, winheight(0) - 2])
  let maxcols = max([1, maxcols])
  let maxrows = max([1, maxrows])
  if a:maxcols>0
    let maxcols = min([a:maxcols, maxcols])
  endif
  if a:maxrows>0
    let maxrows = min([a:maxrows, maxrows])
  endif

  let filename_esc = shellescape(a:filename)
  let command = g:terminal_images2_command .
        \ " --max-cols " . string(maxcols) .
        \ " --max-rows " . string(maxrows) .
        \ " --quiet " .
        \ " -e /dev/null " .
        \ " --only-dump-dims " .
        \ filename_esc
  silent let dims = split(system(command), " ")
  if v:shell_error != 0
    throw "Non-zero exit code: ".string(v:shell_error)." while checking ".filename_esc
  endif
  if len(dims) != 2
    throw "Unexpected output: ".string(dims)
  endif
  let cols = str2nr(dims[0])
  let rows = str2nr(dims[1])
  return [cols, rows]
endfun

fun! GetReadableFile(filename) " str|''
  " Try the current directory and the directory of the current file.
  let filenames = [a:filename, expand('%:p:h') . "/" . a:filename]
  " Try the current netrw directory.
  if exists('b:netrw_curdir')
    call add(filenames, b:netrw_curdir . "/" . a:filename)
  endif
  for filename in filenames
    if filereadable(filename)
      return filename
    endif
  endfor
  " In subdirectories of the directory of the current file (descend one level by default).
  let globpattern = expand('%:p:h') .
              \ "/" . s:Get('terminal_images_subdir_glob') . "/" . a:filename
  let globlist = glob(globpattern, 0, 1)
  for filename in globlist
    if filereadable(filename)
      return filename
    endif
  endfor
  return ""
endfun

fun! FindImages() " [{lnum:int,filename:str}]
  let candidates = []
  for lnum in range(line('w0'), line('w$'))
     if lnum < 1
       continue
     endif
     let line_str = getline(lnum)
     if len(candidates) >= 32
       continue
     endif
     let matches = []
     call substitute(line_str, s:Get('terminal_images2_regex'), '\=add(matches, submatch(1))', 'g')
     for m in matches
       let filename = GetReadableFile(m)
       if len(filename)>0
         call add(candidates, #{lnum:lnum, filename:filename})
       endif
     endfor
  endfor
  return candidates
endfun

function! FindSegments(segments, width, start) abort
  " Initialize the new segment positions
  let new_seg_begin = a:start
  let new_seg_end = new_seg_begin + a:width
  " Iterate through the sorted segments to find a non-overlapping position
  for seg in a:segments
    let seg_begin = seg[0]
    let seg_end = seg[1]
    " Check if the new segment overlaps with the current segment
    if new_seg_begin < seg_end && new_seg_end > seg_begin
      " Move the new segment to the end of the current segment
      let new_seg_begin = seg_end
      let new_seg_end = new_seg_begin + a:width
    endif
  endfor
  " Return the positions of the new segment
  return new_seg_begin
endfun

fun! PopupTest2()
  let filename = "_parabola".".png"
  let [cols, rows] = PopupImageDims(filename, -1, -1)
  let lnum = line('.')

  let prop = PropGetOrCreate(lnum, filename)
  let popup_id = PopupGetOrCreate(filename, prop, 0, prop.lnum, cols, rows)
endfun

fun! PopupTest3()
  let left_margin = s:Get('terminal_images2_left_margin')
  let excluded = []
  for img in FindImages()
    call add(excluded, PropGetIdByUrl(img.filename))
  endfor
  let segments = PopupOccupiedLines(excluded)
  for img in FindImages()
    let filename = img.filename
    let lnum = img.lnum

    let [cols, rows] = PopupImageDims(filename, -1, -1)
    let new_start_pos = FindSegments(segments, rows, line("w0"))
    let prop = PropGetOrCreate(new_start_pos, filename)

    let popup_id = PopupGetOrCreate(filename, prop, left_margin, new_start_pos, cols, rows)
    let seg = PopupOccupiedLines1(popup_id, [])
    if len(seg)>0
      call add(segments, seg)
      let segments = sort(segments, "s:Compare")
    endif
  endfor
endfun

