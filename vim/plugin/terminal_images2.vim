let g:terminal_images2_prop_type_name = 'TerminalImages2Popup'
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

fun! SearchWithinRange(pat, lstart, lstop)
  let [pat,lstart,lstop] = [a:pat, max([1,a:lstart]), a:lstop]
  let [found,c] = [0,"c"]
  let saved_cursor_pos = getpos('.')
  try
    call cursor(lstart,1)
    while search(pat, c."W", lstop) > 0
      let found = found + 1
      let c = ""
    endwhile
  finally
    call setpos('.', saved_cursor_pos)
  endtry
  return found
endfun

fun! SearchWindowBackward(pat, winsz, lbegin)
  let [pat,lbegin,winsz] = [a:pat, max([1,a:lbegin]), a:winsz]
  let lend = max([1,lbegin-winsz])
  let res = []
  let saved_cursor_pos = getpos('.')
  try
    call cursor(lbegin,9999)
    while 1
      let lnum = search(pat, "bW", lend)
      if lnum <= 0
        break
      endif
      call add(res, lnum)
      let lend = max([1, lnum-winsz])
    endwhile
  finally
    call setpos('.', saved_cursor_pos)
  endtry
  return res
endfun

fun! PropGetIdByUrl(lnum, url)
  let [lnum, url] = [a:lnum, a:url]
  let matches = SearchWindowBackward(url, 20, lnum)
  let hash = sha256(url.'-'.string(len(matches)))[:6]
  return str2nr(hash, 16)
endfun

fun! PropCreate(img, lnum, prop_id) " prop
	let prop_id = a:prop_id
  let [lnum, url] = [a:lnum, a:img.url]
  if empty(prop_type_get(g:terminal_images2_prop_type_name))
    call prop_type_add(g:terminal_images2_prop_type_name, {})
  endif
	call prop_add(lnum, 1, #{
        \ length: 0,
        \ type: g:terminal_images2_prop_type_name,
        \ id: prop_id,
        \ })
  " echow "Created prop_id ".string(prop_id). " at lnum ".string(lnum)

  let prop = #{id:prop_id, lnum:lnum}
  return prop
endfun


fun! PropGetOrCreate(img, lnum)
  let [lnum, url] = [a:lnum, a:img.url]
  if lnum > line('$')
    let lnum=line('$')
  endif
	let prop_id = a:img.prop_id
  call prop_remove(#{id:prop_id})
  let props = prop_list(lnum, #{ids: [prop_id]})
  if len(props)==0
    return PropCreate(a:img, lnum, prop_id)
  elseif len(props)==1
    " echow "Found prop_id ".string(prop_id). " at lnum ".string(lnum)
    return #{id:prop_id, lnum:lnum}
  else
    throw "Too many props in line".lnum
  endif
endfun

fun! PopupCreate(img, prop, col, row, cols, rows)
  let background_higroup =
        \ get(b:, 'terminal_images2_background', 'TerminalImagesBackground')

	let popup_id = popup_create('', #{
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
  call setbufvar(winbufnr(popup_id), "filename", a:img.filename)
  " echow "Created popup_id ". string(popup_id). " for prop_id ".string(a:prop.id)
  call PopupUploadImage(popup_id, a:img.filename, a:cols, a:rows)
  return popup_id
endfun

fun! PopupPropId(popup_id) " int | -1
  let opt = popup_getoptions(a:popup_id)
  if get(opt, "textprop", "") == g:terminal_images2_prop_type_name
    return get(opt, "textpropid", -1)
  endif
  return -1
endfun

" Return vertical position of a popup
fun! PopupPosition(popup_id) " [int,int]|[]
  let prop = prop_find(#{lnum:1, id:PopupPropId(a:popup_id)})
  if len(prop)>0
    let opt = popup_getoptions(a:popup_id)
    return [prop.lnum, prop.lnum+opt.maxheight]
  endif
  return []
endfun

fun! IsPopupVisible(popup_id) " int
  return len(PopupPosition(a:popup_id))>0
endfun

fun! s:Compare(a,b)
  if a:a[0]!=a:b[0]
    return a:a[0]>a:b[0]
  else
    return a:a[1]>a:b[1]
  endif
endfun

fun! PopupOccupiedLines_(popup_ids, lstart, lstop) " [[int,int]]
  let ret = []
  for popup_id in a:popup_ids
    let pos = PopupPosition(popup_id)
    if len(pos)>0
      call add(ret, pos)
    endif
  endfor
  return sort(ret, "s:Compare")
endfun

fun! PopupGetOrCreate(img, prop, col, row, cols, rows)
  for popup_id in popup_list()
    let opt = popup_getoptions(popup_id)
    " echow "Checking popup_id".string(popup_id).": ".string(opt)
    if has_key(opt, "textpropid") && opt.textpropid == a:prop.id
      if opt.maxwidth==a:cols && opt.maxheight==a:rows
        " echow "Found popup_id ". string(popup_id). " for prop_id ".string(a:prop.id)
        call popup_move(popup_id, #{line:a:row-a:prop.lnum-1})
        let pos = popup_getpos(popup_id)
        if !pos.visible
          call popup_show(popup_id)
        endif
        return popup_id
      else
        call popup_close(popup_id)
        " echow "Re-creating popup for prop_id ".string(a:prop.id)
        break
      endif
    endif
  endfor
  let popup_id = PopupCreate(a:img, a:prop, a:col, a:row, a:cols, a:rows)
  return popup_id
endfun

fun! PopupUploadImage(popup_id, filename, cols, rows)
  let props = popup_getpos(a:popup_id)
  " echow string(props)
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

let g:terminal_images2_dim_cache = {}

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

  let cached_dims = get(g:terminal_images2_dim_cache, command, [])
  if len(cached_dims)>0
    let res = cached_dims
  else
    silent let dims = split(system(command), " ")
    if v:shell_error != 0
      throw "Non-zero exit code: ".string(v:shell_error)." while checking ".filename_esc
    endif
    if len(dims) != 2
      throw "Unexpected output: ".string(dims)
    endif
    let cols = str2nr(dims[0])
    let rows = str2nr(dims[1])
    let res = [cols, rows]
    let g:terminal_images2_dim_cache[command] = res
  endif
  return res
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

fun! FindImages(lstart, lstop) " [{lnum:int, url:str, filename:str, prop_id:int}]
  let candidates = []
  for lnum in range(a:lstart, a:lstop)
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
         call add(candidates,
               \ #{lnum:lnum, url:m, filename:filename, prop_id:PropGetIdByUrl(lnum, m)})
       endif
     endfor
  endfor
  return candidates
endfun

function! PositionSegment(segments, width, start) abort
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

" Find all poopups overlapping with the `[lstart,lstop]` interval.
fun! PopupFindWithin(lstart, lstop) " [popup_id]
  let acc = []
  for popup_id in popup_list()
    let pos = PopupPosition(popup_id)
    if len(pos)>0
      if pos[1]>=a:lstart || pos[0]<=a:lstop
        call add(acc, popup_id)
      endif
    endif
  endfor
  return acc
endfun

fun! PopupFindOutdated_(popup_ids, images, lstart, lstop) " [popup_id]
  let prop_ids = []
  for img in a:images
    call add(prop_ids, img.prop_id)
  endfor
  let popup_ids = a:popup_ids
  let outdated = []
  for popup_id in popup_ids
    let popup_prop_id = PopupPropId(popup_id)
    if popup_prop_id<0 || index(prop_ids, popup_prop_id)<0
      call add(outdated, popup_id)
    endif
  endfor
  return outdated
endfun

fun! PopupFindOutdated(lstart, lstop) " [popup_id]
  return PopupFindOutdated_(
        \ PopupFindWithin(a:lstart, a:lstop),
        \ FindImages(a:lstart, a:lstop),
        \ a:lstart, a:lstop)
endfun

fun! Update(line_start, line_stop)
  let [line_start, line_stop] = [a:line_start, a:line_stop]
  let left_margin = s:Get('terminal_images2_left_margin')

  let images = FindImages(line_start, line_stop)
  let all_popup_ids = PopupFindWithin(line_start, line_stop)
  let modified_popup_ids = []
  let segments = []
  for img in images
    let [cols, rows] = PopupImageDims(img.filename, -1, -1)
    let new_start_pos = PositionSegment(segments, rows, line_start)
    if new_start_pos <= line_stop
      let prop = PropGetOrCreate(img, new_start_pos)
      let popup_id = PopupGetOrCreate(img, prop, left_margin, prop.lnum, cols, rows)
      let seg = PopupPosition(popup_id)
      if len(seg)>0
        call add(segments, seg)
        let segments = sort(segments, "s:Compare")
        call add(modified_popup_ids, popup_id)
      endif
    endif
  endfor
  for popup_id in all_popup_ids
    if count(modified_popup_ids, popup_id)==0
      call popup_close(popup_id)
    endif
  endfor
endfun

fun! UpdateScreen()
  call Update(line('w0'),line('w$'))
endfun
