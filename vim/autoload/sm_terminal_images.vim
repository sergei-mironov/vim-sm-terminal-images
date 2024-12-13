fun! s:GetDef(name, def) abort
  return get(b:, a:name, get(g:, a:name, a:def))
endfun
fun! s:Get(name) abort
  return s:GetDef(a:name, 0)
endfun

" https://stackoverflow.com/questions/26315925/get-usable-window-width-in-vim-script
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

fun! sm_terminal_images#SearchWithinRange(pat, lstart, lstop)
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

fun! sm_terminal_images#SearchWindowBackward(pat, winsz, lbegin)
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

fun! sm_terminal_images#PropGetIdByUrl(lnum, url)
  let [lnum, url] = [a:lnum, a:url]
  let matches = sm_terminal_images#SearchWindowBackward(url, 20, lnum)
  let hash = sha256(url.'-'.string(len(matches)))[:6]
  return str2nr(hash, 16)
endfun

fun! sm_terminal_images#PropCreate(img, lnum, prop_id) " prop
	let prop_id = a:prop_id
  let [lnum, url] = [a:lnum, a:img.url]
  if empty(prop_type_get(g:sm_terminal_images_prop_type_name))
    call prop_type_add(g:sm_terminal_images_prop_type_name, {})
  endif
	call prop_add(lnum, 1, #{
        \ length: 0,
        \ type: g:sm_terminal_images_prop_type_name,
        \ id: prop_id,
        \ })
  " echow "Created prop_id ".string(prop_id). " at lnum ".string(lnum)

  let prop = #{id:prop_id, lnum:lnum}
  return prop
endfun


fun! sm_terminal_images#PropGetOrCreate(img, lnum)
  let [lnum, url] = [a:lnum, a:img.url]
  if lnum > line('$')
    let lnum=line('$')
  endif
	let prop_id = a:img.prop_id
  call prop_remove(#{id:prop_id})
  let props = prop_list(lnum, #{ids: [prop_id]})
  if len(props)==0
    return sm_terminal_images#PropCreate(a:img, lnum, prop_id)
  elseif len(props)==1
    " echow "Found prop_id ".string(prop_id). " at lnum ".string(lnum)
    return #{id:prop_id, lnum:lnum}
  else
    throw "Too many props in line".lnum
  endif
endfun

fun! sm_terminal_images#PopupCreate(img, prop, col, row, cols, rows)
  let background_higroup =
        \ s:GetDef('sm_terminal_images_background', 'SMTerminalImagesBackground')

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
        \ textprop: g:sm_terminal_images_prop_type_name,
        \ textpropid: a:prop.id,
        \ })
  call setbufvar(winbufnr(popup_id), "filename", a:img.filename)
  " echow "Created popup_id ". string(popup_id). " for prop_id ".string(a:prop.id)
  call sm_terminal_images#PopupUploadImage(popup_id, a:img.filename, a:cols, a:rows)
  return popup_id
endfun

fun! sm_terminal_images#PopupPropId(popup_id) " int | -1
  let opt = popup_getoptions(a:popup_id)
  if get(opt, "textprop", "") == g:sm_terminal_images_prop_type_name
    return get(opt, "textpropid", -1)
  endif
  return -1
endfun

" Return vertical position of a popup
fun! sm_terminal_images#PopupPosition(popup_id) " [int,int]|[]
  let prop = prop_find(#{lnum:1, id:sm_terminal_images#PopupPropId(a:popup_id)})
  if len(prop)>0
    let opt = popup_getoptions(a:popup_id)
    return [prop.lnum, prop.lnum+opt.maxheight]
  endif
  return []
endfun

fun! sm_terminal_images#IsPopupVisible(popup_id) " int
  return len(sm_terminal_images#PopupPosition(a:popup_id))>0
endfun

fun! s:Compare(a,b)
  if a:a[0]!=a:b[0]
    return a:a[0]>a:b[0]
  else
    return a:a[1]>a:b[1]
  endif
endfun

fun! sm_terminal_images#PopupOccupiedLines_(popup_ids, lstart, lstop) " [[int,int]]
  let ret = []
  for popup_id in a:popup_ids
    let pos = sm_terminal_images#PopupPosition(popup_id)
    if len(pos)>0
      call add(ret, pos)
    endif
  endfor
  return sort(ret, "s:Compare")
endfun

fun! sm_terminal_images#PopupGetOrCreate(img, prop, col, row, cols, rows)
  for popup_id in popup_list()
    let opt = popup_getoptions(popup_id)
    " echow "Checking popup_id".string(popup_id).": ".string(opt)
    if has_key(opt, "textpropid") && opt.textpropid == a:prop.id
      if opt.maxwidth==a:cols && opt.maxheight==a:rows
        " echow "Found popup_id ". string(popup_id). " for prop_id ".string(a:prop.id)
        call popup_move(popup_id, #{line:a:row-a:prop.lnum-1})
        call popup_show(popup_id)
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
  let popup_id = sm_terminal_images#PopupCreate(a:img, a:prop, a:col, a:row, a:cols, a:rows)
  return popup_id
endfun

fun! sm_terminal_images#PopupUploadImage(popup_id, filename, cols, rows)
  " echow string(props)
  let [filename, cols, rows] = [a:filename, a:cols, a:rows]
  try
    let text = sm_terminal_images#UploadTerminalImage(filename,
          \ {'cols': cols,
          \  'rows': rows,
          \  'flags': ""
          \ })

    call popup_settext(a:popup_id, text)
  catch
    echomsg "Interrupted:" .v:exception
  endtry
endfun

let g:sm_terminal_images_dim_cache = {}

fun! sm_terminal_images#PopupImageDims(filename, maxcols, maxrows) " -> [int,int]|v:null
  let win_width = s:GetWindowWidth()
  let maxcols = s:Get('sm_terminal_images_max_columns')
  let maxrows = s:Get('sm_terminal_images_max_rows')
  let right_margin = s:Get('sm_terminal_images_right_margin')
  let left_margin = s:Get('sm_terminal_images_left_margin')
  let maxcols = min([maxcols, &columns, win_width - right_margin - left_margin])
  let maxrows = min([maxrows, &lines, winheight(0) - 2])
  let maxcols = max([0, maxcols])
  let maxrows = max([0, maxrows])
  if a:maxcols>0
    let maxcols = min([a:maxcols, maxcols])
  endif
  if a:maxrows>0
    let maxrows = min([a:maxrows, maxrows])
  endif
  if maxcols==0 || maxrows==0
    return v:null
  endif

  let filename_esc = shellescape(a:filename)
  let command = g:sm_terminal_images_command .
        \ " --max-cols " . string(maxcols) .
        \ " --max-rows " . string(maxrows) .
        \ " --quiet " .
        \ " -e /dev/null " .
        \ " --only-dump-dims " .
        \ filename_esc

  let cached_dims = get(g:sm_terminal_images_dim_cache, command, [])
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
    let g:sm_terminal_images_dim_cache[command] = res
  endif
  return res
endfun

fun! sm_terminal_images#GetReadableFile(filename) " str|''
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
              \ "/" . s:Get('sm_terminal_images_subdir_glob') . "/" . a:filename
  let globlist = glob(globpattern, 0, 1)
  for filename in globlist
    if filereadable(filename)
      return filename
    endif
  endfor
  return ""
endfun

fun! sm_terminal_images#FindImages(lstart, lstop) " [{lnum:int, url:str, filename:str, prop_id:int}]
  let candidates = []
  let seen_filenames = {} " Dictionary to track seen filenames
  for lnum in range(a:lstart, a:lstop)
     if lnum < 1
       continue
     endif
     let line_str = getline(lnum)
     if len(candidates) >= 32
       continue
     endif
     let matches = []
     call substitute(line_str, s:Get('sm_terminal_images_regex'), '\=add(matches, submatch(1))', 'g')
     for m in matches
       let filename = sm_terminal_images#GetReadableFile(m)
       if len(filename)>0 && !has_key(seen_filenames, filename) " Check if the filename is new
         call add(candidates,
               \ #{lnum:lnum, url:m, filename:filename,
               \ prop_id:sm_terminal_images#PropGetIdByUrl(lnum, m)})
         let seen_filenames[filename] = 1 " Mark this filename as seen
       endif
     endfor
  endfor
  return candidates
endfun

fun! sm_terminal_images#PositionSegment(segments, width, start) abort
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
fun! sm_terminal_images#PopupFindWithin(lstart, lstop) " [popup_id]
  let acc = []
  for popup_id in popup_list()
    let pos = sm_terminal_images#PopupPosition(popup_id)
    if len(pos)>0
      if pos[1]>=a:lstart || pos[0]<=a:lstop
        call add(acc, popup_id)
      endif
    endif
  endfor
  return acc
endfun

fun! sm_terminal_images#PopupFindOutdated_(popup_ids, images, lstart, lstop) " [popup_id]
  let prop_ids = []
  for img in a:images
    call add(prop_ids, img.prop_id)
  endfor
  let popup_ids = a:popup_ids
  let outdated = []
  for popup_id in popup_ids
    let popup_prop_id = sm_terminal_images#PopupPropId(popup_id)
    if popup_prop_id<0 || index(prop_ids, popup_prop_id)<0
      call add(outdated, popup_id)
    endif
  endfor
  return outdated
endfun

fun! sm_terminal_images#PopupFindOutdated(lstart, lstop) " [popup_id]
  return sm_terminal_images#PopupFindOutdated_(
        \ sm_terminal_images#PopupFindWithin(a:lstart, a:lstop),
        \ sm_terminal_images#FindImages(a:lstart, a:lstop),
        \ a:lstart, a:lstop)
endfun

fun! sm_terminal_images#Update(line_start, line_stop)
  let [line_start, line_stop] = [a:line_start, a:line_stop]
  let left_margin = s:Get('sm_terminal_images_left_margin')

  let images = sm_terminal_images#FindImages(line_start, line_stop)
  let all_popup_ids = sm_terminal_images#PopupFindWithin(line_start, line_stop)
  let modified_popup_ids = []
  let segments = []
  for img in images
    let pos = sm_terminal_images#PopupImageDims(img.filename, -1, -1)
    if pos == v:null
      continue
    endif
    let [cols, rows] = pos
    let new_start_pos = sm_terminal_images#PositionSegment(segments, rows, line_start)
    if new_start_pos <= line_stop
      let prop = sm_terminal_images#PropGetOrCreate(img, new_start_pos)
      let popup_id = sm_terminal_images#PopupGetOrCreate(img, prop, left_margin, prop.lnum, cols, rows)
      let seg = sm_terminal_images#PopupPosition(popup_id)
      if len(seg)>0
        call add(segments, seg)
        let segments = sort(segments, "s:Compare")
        call add(modified_popup_ids, popup_id)
      endif
    endif
  endfor
  for popup_id in all_popup_ids
    if count(modified_popup_ids, popup_id)==0
      call popup_hide(popup_id)
    endif
  endfor
endfun

fun! sm_terminal_images#UpdateVisible()
  call sm_terminal_images#Update(line('w0'),line('w$'))
endfun

fun! sm_terminal_images#ShowUnderCursor(...) abort
  let silent = get(a:, 0, 0)
  try
    let filename = sm_terminal_images#GetReadableFile(expand('<cfile>'))
  catch
    if !silent
      echohl ErrorMsg
      echo v:exception
      echohl None
    endif
    return 0
  endtry
  if !filereadable(filename)
    return
  endif
  if !silent
    let uploading_popup =
                  \ popup_atcursor("Uploading " . filename, {'zindex': 1010})
  endif
  redraw
  echo "Uploading " . filename
  try
    let text = terminal_images#UploadTerminalImage(filename, {})
    redraw
    echo "Showing " . filename
  catch
    if !silent
      call popup_close(uploading_popup)
    endif
    " Vim doesn't want to redraw unless I put echo in between
    redraw!
    echo
    redraw!
    echohl ErrorMsg
    echo v:exception
    echohl None
    return
  endtry
  if !silent
    call popup_close(uploading_popup)
  endif
  let background_higroup =
              \ s:GetDef('sm_terminal_images_background', 'SMTerminalImagesBackground')
  return popup_atcursor(text,
              \ #{wrap: 0, highlight: background_higroup, zindex: 1000})
endfun

" Upload the given image with the given size. If `cols` and `rows` are zero, the
" best size will be computed automatically.
" The result of this function is a list of lines with text properties
" representing the image (can be used with popup_create and popup_settext).
function! sm_terminal_images#UploadTerminalImage(filename, params) abort
  let cols = get(a:params, 'cols', 0)
  let rows = get(a:params, 'rows', 0)
  let flags = get(a:params, 'flags', '')
  " If the number of columns and rows is not provided, the script will compute
  " them automatically. We just need to limit the number of columns and rows
  " so that the image fits in the window.
  let maxcols = s:Get('sm_terminal_images_max_columns')
  let maxrows = s:Get('sm_terminal_images_max_rows')
  let right_margin = s:Get('sm_terminal_images_right_margin')
  let maxcols = min([maxcols, &columns, s:GetWindowWidth() - right_margin])
  let maxrows = min([maxrows, &lines, winheight(0) - 2])
  let maxcols = max([1, maxcols])
  let maxrows = max([1, maxrows])
  let maxcols_str = cols ? "" : " --max-cols " . string(maxcols)
  let maxrows_str = rows ? "" : " --max-rows " . string(maxrows)
  let cols_str = cols ? " -c " . shellescape(string(cols)) : ""
  let rows_str = rows ? " -r " . shellescape(string(rows)) : ""
  let filename_expanded = resolve(expand(a:filename))
  let filename_str = shellescape(filename_expanded)
  let outfile = tempname()
  let errfile = tempname()
  let infofile = tempname()
  try
    " We use tupimage to upload the file. We ask it to write lines
    " representing the image to `outfile` and disable outputting escape codes
    " for the image id (--noesc) because we assign them by ourselves using text
    " properties.
    let command = g:sm_terminal_images_command .
          \ cols_str .
          \ rows_str .
          \ maxcols_str .
          \ maxrows_str .
          \ " -o " . shellescape(outfile) .
          \ " --save-info " . shellescape(infofile) .
          \ " --noesc " .
          \ " --256 " .
          \ " --quiet " .
          \ flags .
          \ " " . filename_str .
          \ " 2> " . shellescape(errfile)
    call system(command)
    if v:shell_error != 0
      if filereadable(errfile)
        let err_message = readfile(errfile)[0]
        throw "Error: " . err_message . "  Command: " . command
      endif
      throw "Command failed: " . command
    endif

    " Get image id from infofile.
    let id = ''
    for infoline in readfile(infofile)
      " The line we want looks something like "id 1234"
      let id = matchstr(infoline, '^id[ \t]\+\zs[0-9]\+\ze$')
      if id != ''
        break
      endif
    endfor
    if id == ''
      throw "Could not read id from " . infofile
    endif

    " Read outfile and convert it to something suitable for floating windows.
    let lines = readfile(outfile)
    let result = []
    " We use text properties to assign each line the foreground color
    " corresponding to the image id.
    let prop_type = "SMTerminalImagesID" . id
    for line in lines
      call add(result,
            \ {'text': line,
            \  'props': [{'col': 1,
            \             'length': len(line),
            \             'type': prop_type}]})
    endfor
  finally
    if filereadable(errfile)
      call delete(errfile)
    endif
    if filereadable(infofile)
      call delete(infofile)
    endif
    if filereadable(outfile)
      call delete(outfile)
    endif
  endtry
  return result
endfun
