"=============================================================================
" FILE: vimfiler.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 23 Sep 2011.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Version: 3.0, for Vim 7.0
"=============================================================================

" Check vimproc.
try
  call vimproc#version()
  let s:exists_vimproc = 1
catch
  let s:exists_vimproc = 0
endtry

" Check unite.vim."{{{
try
  let s:exists_unite_version = unite#version()
catch
  echoerr v:errmsg
  echoerr v:exception
  echoerr 'Error occured while loading unite.vim.'
  echoerr 'Please install unite.vim Ver.3.0 or above.'
  finish
endtry
if s:exists_unite_version < 300
  echoerr 'Your unite.vim is too old.'
  echoerr 'Please install unite.vim Ver.3.0 or above.'
  finish
endif"}}}

let s:last_vimfiler_bufnr = -1
let s:last_system_is_vimproc = -1

" Global options definition."{{{
if !exists('g:vimfiler_execute_file_list')
  let g:vimfiler_execute_file_list = {}
endif
"}}}

augroup vimfiler"{{{
  autocmd!
augroup end"}}}

" User utility functions."{{{
function! vimfiler#default_settings()"{{{
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal noreadonly
  setlocal nomodifiable
  setlocal nowrap
  setlocal nofoldenable
  setlocal foldcolumn=0
  setlocal nolist
  if has('netbeans_intg') || has('sun_workshop')
    setlocal noautochdir
  endif
  let &l:winwidth = g:vimfiler_min_filename_width + 10
  if has('conceal')
    setlocal conceallevel=3
    setlocal concealcursor=n
  endif
  if exists('&colorcolumn')
    setlocal colorcolumn=
  endif

  " Set autocommands.
  augroup vimfiler"{{{
    autocmd WinEnter,BufWinEnter <buffer> call s:event_bufwin_enter()
    autocmd BufWinEnter <buffer> call s:restore_vimfiler()
    autocmd WinLeave,BufWinLeave <buffer> call s:event_bufwin_leave()
    autocmd VimResized <buffer> call vimfiler#redraw_all_vimfiler()
  augroup end"}}}

  call vimfiler#mappings#define_default_mappings()
endfunction"}}}
function! vimfiler#set_execute_file(exts, command)"{{{
  for ext in split(a:exts, ',')
    let g:vimfiler_execute_file_list[ext] = a:command
  endfor
endfunction"}}}
function! vimfiler#set_extensions(kind, exts)"{{{
  let g:vimfiler_extensions[a:kind] = {}
  for ext in split(a:exts, ',')
    let g:vimfiler_extensions[a:kind][ext] = 1
  endfor
endfunction"}}}
"}}}

" vimfiler plugin utility functions."{{{
function! vimfiler#create_filer(path, ...)"{{{
  let context = vimfiler#init_context(get(a:000, 0, {}))

  " Create new buffer.
  let prefix = vimfiler#iswin() ? '[vimfiler]' : '*vimfiler*'
  let postfix = ' - 1'
  let cnt = 1
  while buflisted(prefix.postfix)
    let cnt += 1
    let postfix = ' - ' . cnt
  endwhile
  let bufname = prefix.postfix

  if context.is_split
    silent vsplit `=bufname`
  else
    silent edit `=bufname`
  endif

  let path = (a:path == '') ?
        \ vimfiler#util#substitute_path_separator(getcwd()) : a:path
  let context.path = path
  " echomsg path

  call vimfiler#handler#_event_handler('BufReadCmd', context)
endfunction"}}}
function! vimfiler#switch_filer(path, ...)"{{{
  let context = vimfiler#init_context(get(a:000, 0, {}))

  " Search vimfiler buffer.
  if buflisted(s:last_vimfiler_bufnr)
        \ && getbufvar(s:last_vimfiler_bufnr, '&filetype') ==# 'vimfiler'
        \ && (!exists('t:unite_buffer_dictionary')
        \      || has_key(t:unite_buffer_dictionary, s:last_vimfiler_bufnr))
    call s:switch_vimfiler(s:last_vimfiler_bufnr, context, a:path)
    return
  endif

  " Search vimfiler buffer.
  let cnt = 1
  while cnt <= bufnr('$')
    if getbufvar(cnt, '&filetype') ==# 'vimfiler'
        \ && (!exists('t:unite_buffer_dictionary')
        \     || has_key(t:unite_buffer_dictionary, cnt))
      call s:switch_vimfiler(cnt, context, a:path)
      return
    endif

    let cnt += 1
  endwhile

  " Create window.
  call vimfiler#create_filer(a:path, context)
endfunction"}}}
function! vimfiler#get_all_files()"{{{
  " Save current files.

  let context = {
        \ 'vimfiler__is_dummy' : 0,
        \ }
  let current_files = unite#get_vimfiler_candidates(
        \ [[b:vimfiler.source, b:vimfiler.current_dir]], context)

  let dirs = filter(copy(current_files), 'v:val.vimfiler__is_directory')
  let files = filter(copy(current_files), '!v:val.vimfiler__is_directory')
  if g:vimfiler_directory_display_top
    let current_files = vimfiler#sort(dirs, b:vimfiler.sort_type)
          \+ vimfiler#sort(files, b:vimfiler.sort_type)
  else
    let current_files = vimfiler#sort(files + dirs, b:vimfiler.sort_type)
  endif

  if !b:vimfiler.is_visible_dot_files
    call filter(current_files, 'v:val.vimfiler__filename !~ "^\\."')
  endif

  return current_files
endfunction"}}}
function! vimfiler#force_redraw_screen()"{{{
  " Use matcher_glob.
  let b:vimfiler.current_files =
        \ unite#filters#matcher_vimfiler_mask#define().filter(
        \ vimfiler#get_all_files(), { 'input' : b:vimfiler.current_mask })

  call vimfiler#redraw_screen()
endfunction"}}}
function! vimfiler#redraw_screen()"{{{
  if !has_key(b:vimfiler, 'current_files')
    return
  endif

  setlocal modifiable
  let pos = getpos('.')

  " Clean up the screen.
  % delete _

  call vimfiler#redraw_prompt()

  " Append up directory.
  call append('$', '..')

  " Print files.
  let is_simple = b:vimfiler.is_simple ||
        \ winwidth(0) < g:vimfiler_min_filename_width * 2
  let max_len = is_simple ?
        \ g:vimfiler_min_filename_width : (winwidth(0) - g:vimfiler_min_filename_width)
  if max_len > g:vimfiler_max_filename_width
    let max_len = g:vimfiler_max_filename_width
  endif
  let max_len -= 1
  for file in b:vimfiler.current_files
    let filename = file.vimfiler__abbr
    if file.vimfiler__is_directory
          \ && filename !~ '/$'
      let filename .= '/'
    endif
    let filename = vimfiler#util#truncate_smart(
          \ filename, max_len, max_len/3, '..')

    let mark = file.vimfiler__is_marked ? '*' : '-'
    if !is_simple
      let line = printf('%s %s %s %s %s',
            \ mark,
            \ filename,
            \ file.vimfiler__filetype,
            \ vimfiler#get_filesize(file),
            \ file.vimfiler__datemark . strftime(g:vimfiler_time_format, file.vimfiler__filetime)
            \)
    else
      let line = printf('%s %s %s', mark, filename, file.vimfiler__filetype)
    endif

    call append('$', line)
  endfor

  call setpos('.', pos)
  setlocal nomodifiable
endfunction"}}}
function! vimfiler#redraw_prompt()"{{{
  let modifiable_save = &l:modifiable
  setlocal modifiable
  call setline(1, printf('%s%s%s:%s[%s%s]',
        \ (b:vimfiler.is_safe_mode ? '' : b:vimfiler.is_simple ? '*u* ' : '*unsafe* '),
        \ (b:vimfiler.is_simple ? 'CD: ' : 'Current directory: '),
        \ b:vimfiler.source, b:vimfiler.current_dir,
        \ (b:vimfiler.is_visible_dot_files ? '.:' : ''),
        \ b:vimfiler.current_mask))
  let &l:modifiable = modifiable_save
endfunction"}}}
function! vimfiler#iswin()"{{{
  return has('win32') || has('win64')
endfunction"}}}
function! vimfiler#exists_vimproc()"{{{
  return s:exists_vimproc
endfunction"}}}
function! vimfiler#system(str, ...)"{{{
  let s:last_system_is_vimproc = vimfiler#exists_vimproc()

  let command = a:str
  let input = join(a:000)
  if &termencoding != '' && &termencoding != &encoding
    let command = iconv(command, &encoding, &termencoding)
    let input = iconv(input, &encoding, &termencoding)
  endif

  let output = vimfiler#exists_vimproc() ? (a:0 == 0 ? vimproc#system(command) : vimproc#system(command, input))
        \: (a:0 == 0 ? system(command) : system(command, input))
  if &termencoding != '' && &termencoding != &encoding
    let output = iconv(output, &termencoding, &encoding)
  endif
  return output
endfunction"}}}
function! vimfiler#force_system(str, ...)"{{{
  let s:last_system_is_vimproc = 0

  let command = a:str
  let input = join(a:000)
  if &termencoding != '' && &termencoding != &encoding
    let command = iconv(command, &encoding, &termencoding)
    let input = iconv(input, &encoding, &termencoding)
  endif
  let output = (a:0 == 0)? system(command) : system(command, input)
  if &termencoding != '' && &termencoding != &encoding
    let output = iconv(output, &termencoding, &encoding)
  endif
  return output
endfunction"}}}
function! vimfiler#get_system_error()"{{{
  if s:last_system_is_vimproc
    return vimproc#get_last_status()
  else
    return v:shell_error
  endif
endfunction"}}}
function! vimfiler#get_marked_files()"{{{
  let files = []
  let max = line('$')
  let cnt = 1
  while cnt <= max
    let line = getline(cnt)
    if line =~ '^[*] '
      " Marked.
      call add(files, vimfiler#get_file(cnt))
    endif

    let cnt += 1
  endwhile

  return files
endfunction"}}}
function! vimfiler#get_marked_filenames()"{{{
  let files = []
  let max = line('$')
  let cnt = 1
  while cnt <= max
    let line = getline(cnt)
    if line =~ '^[*] '
      " Marked.
      call add(files, vimfiler#get_filename(cnt))
    endif

    let cnt += 1
  endwhile

  return files
endfunction"}}}
function! vimfiler#get_escaped_marked_files()"{{{
  let files = []
  let max = line('$')
  let cnt = 1
  while cnt <= max
    let line = getline(cnt)
    if line =~ '^[*] '
      " Marked.
      call add(files, '"' . vimfiler#get_filename(cnt) . '"')
    endif

    let cnt += 1
  endwhile

  return files
endfunction"}}}
function! vimfiler#check_filename_line(...)"{{{
  let line = (a:0 == 0)? getline('.') : a:1
  return line =~ '^[*-]\s'
endfunction"}}}
function! vimfiler#get_filename(line_num)"{{{
  return a:line_num == 1 ? '' :
   \ getline(a:line_num) == '..' ? '..' :
   \ b:vimfiler.current_files[a:line_num - 3].action__path
endfunction"}}}
function! vimfiler#get_file(line_num)"{{{
  return getline(a:line_num) == '..' ? {} : b:vimfiler.current_files[a:line_num - 3]
endfunction"}}}
function! vimfiler#input_directory(message)"{{{
  echo a:message
  let dir = input('', '', 'dir')
  while !isdirectory(dir)
    redraw
    if dir == ''
      echo 'Canceled.'
      break
    endif

    " Retry.
    call vimfiler#print_error('Invalid path.')
    echo a:message
    let dir = input('', '', 'dir')
  endwhile

  return dir
endfunction"}}}
function! vimfiler#input_yesno(message)"{{{
  let yesno = input(a:message . ' [yes/no] : ')
  while yesno !~? '^\%(y\%[es]\|n\%[o]\)$'
    redraw
    if yesno == ''
      echo 'Canceled.'
      break
    endif

    " Retry.
    call vimfiler#print_error('Invalid input.')
    let yesno = input(a:message . ' [yes/no] : ')
  endwhile

  return yesno =~? 'y\%[es]'
endfunction"}}}
function! vimfiler#force_redraw_all_vimfiler()"{{{
  let current_nr = winnr()
  let bufnr = 1
  while bufnr <= winnr('$')
    " Search vimfiler window.
    if getwinvar(bufnr, '&filetype') ==# 'vimfiler'

      execute bufnr . 'wincmd w'
      call vimfiler#force_redraw_screen()
    endif

    let bufnr += 1
  endwhile

  execute current_nr . 'wincmd w'
endfunction"}}}
function! vimfiler#redraw_all_vimfiler()"{{{
  let current_nr = winnr()
  let bufnr = 1
  while bufnr <= winnr('$')
    " Search vimfiler window.
    if getwinvar(bufnr, '&filetype') ==# 'vimfiler'

      execute bufnr . 'wincmd w'
      call vimfiler#redraw_screen()
    endif

    let bufnr += 1
  endwhile

  execute current_nr . 'wincmd w'
endfunction"}}}
function! vimfiler#get_filetype(file)"{{{
  let ext = tolower(a:file.vimfiler__extension)

  if (vimfiler#iswin() && ext ==? 'LNK')
    return '[LNK]'
  elseif a:file.vimfiler__is_directory
    return '[DIR]'
  elseif has_key(g:vimfiler_extensions.text, ext)
    " Text.
    return '[TXT]'
  elseif has_key(g:vimfiler_extensions.image, ext)
    " Image.
    return '[IMG]'
  elseif has_key(g:vimfiler_extensions.archive, ext)
    " Archive.
    return '[ARC]'
  elseif has_key(g:vimfiler_extensions.multimedia, ext)
    " Multimedia.
    return '[MUL]'
  elseif a:file.vimfiler__filename =~ '^\.'
        \ || has_key(g:vimfiler_extensions.system, ext)
    " System.
    return '[SYS]'
  elseif a:file.vimfiler__is_executable
    " Execute.
    return '[EXE]'
  else
    " Others filetype.
    return '     '
  endif
endfunction"}}}
function! vimfiler#get_filesize(file)"{{{
  if a:file.vimfiler__is_directory
    return '       '
  endif

  " Get human file size.
  if a:file.vimfiler__filesize < 0
    " Above 2GB.
    let suffix = 'G'
    let mega = (a:file.vimfiler__filesize+1073741824+1073741824) / 1024 / 1024
    let float = (mega%1024)*100/1024
    let pattern = printf('%d.%d', 2+mega/1024, float)
  elseif a:file.vimfiler__filesize >= 1073741824
    " GB.
    let suffix = 'G'
    let mega = a:file.vimfiler__filesize / 1024 / 1024
    let float = (mega%1024)*100/1024
    let pattern = printf('%d.%d', mega/1024, float)
  elseif a:file.vimfiler__filesize >= 1048576
    " MB.
    let suffix = 'M'
    let kilo = a:file.vimfiler__filesize / 1024
    let float = (kilo%1024)*100/1024
    let pattern = printf('%d.%d', kilo/1024, float)
  elseif a:file.vimfiler__filesize >= 1024
    " KB.
    let suffix = 'K'
    let float = (a:file.vimfiler__filesize%1024)*100/1024
    let pattern = printf('%d.%d', a:file.vimfiler__filesize/1024, float)
  else
    " B.
    let suffix = 'B'
    let float = ''
    let pattern = printf('%6d', a:file.vimfiler__filesize)
  endif

  return printf('%s%s%s', pattern[:5], repeat(' ', 6-len(pattern)), suffix)
endfunction"}}}
function! vimfiler#get_datemark(file)"{{{
  let time = localtime() - a:file.vimfiler__filetime
  if time < 86400
    " 60 * 60 * 24
    return '!'
  elseif time < 604800
    " 60 * 60 * 24 * 7
    return '#'
  else
    return '~'
  endif
endfunction"}}}
function! vimfiler#head_match(checkstr, headstr)"{{{
  return stridx(a:checkstr, a:headstr) == 0
endfunction"}}}
function! vimfiler#exists_another_vimfiler()"{{{
  let winnr = bufwinnr(b:vimfiler.another_vimfiler_bufnr)
  return winnr > 0 && getwinvar(winnr, '&filetype') ==# 'vimfiler'
endfunction"}}}
function! vimfiler#bufnr_another_vimfiler()"{{{
  return vimfiler#exists_another_vimfiler() ?
        \ s:last_vimfiler_bufnr : -1
endfunction"}}}
function! vimfiler#winnr_another_vimfiler()"{{{
  return vimfiler#exists_another_vimfiler() ?
        \ bufwinnr(b:vimfiler.another_vimfiler_bufnr) : -1
endfunction"}}}
function! vimfiler#get_another_vimfiler()"{{{
  return vimfiler#exists_another_vimfiler() ?
        \ getbufvar(b:vimfiler.another_vimfiler_bufnr, 'vimfiler') : ''
endfunction"}}}
function! vimfiler#resolve(filename)"{{{
  return ((vimfiler#iswin() && fnamemodify(a:filename, ':e') ==? 'LNK') || getftype(a:filename) ==# 'link') ?
        \ vimfiler#util#substitute_path_separator(resolve(a:filename)) : a:filename
endfunction"}}}
function! vimfiler#print_error(message)"{{{
  echohl WarningMsg | echo a:message | echohl None
endfunction"}}}
function! vimfiler#set_variables(variables)"{{{
  let variables_save = {}
  for [key, value] in items(a:variables)
    let save_value = exists(key) ? eval(key) : ''

    let variables_save[key] = save_value
    execute 'let' key '= value'
  endfor
  
  return variables_save
endfunction"}}}
function! vimfiler#restore_variables(variables_save)"{{{
  for [key, value] in items(a:variables_save)
    execute 'let' key '= value'
  endfor
endfunction"}}}
function! vimfiler#parse_path(path)"{{{
  let source_name = matchstr(a:path, '^[^:]*\ze:')
  if (vimfiler#iswin() && len(source_name) == 1)
        \ || source_name == ''
    " Default source.
    let source_name = 'file'
    let source_arg = a:path
  else
    let source_arg = a:path[len(source_name)+1 :]
  endif

  return [source_name, source_arg]
endfunction"}}}
function! vimfiler#init_context(context)"{{{
  if !has_key(a:context, 'is_split')
    let a:context.is_split = 0
  endif
  if !has_key(a:context, 'is_simple')
    let a:context.is_simple = 0
  endif
  if !has_key(a:context, 'is_double')
    let a:context.is_double = 0
  endif

  return a:context
endfunction"}}}

"}}}

" Sort.
function! vimfiler#sort(files, type)"{{{
  if a:type =~? '^n\%[one]$'
    " Ignore.
    let files = a:files
  elseif a:type =~? '^s\%[ize]$'
    let files = sort(a:files, 's:compare_size')
  elseif a:type =~? '^e\%[xtension]$'
    let files = sort(a:files, 's:compare_extension')
  elseif a:type =~? '^f\%[ilename]$'
    let files = sort(a:files, 's:compare_name')
  elseif a:type =~? '^t\%[ime]$'
    let files = sort(a:files, 's:compare_time')
  elseif a:type =~? '^m\%[anual]$'
    " Not implemented.
    let files = a:files
  else
    throw 'Invalid sort type.'
  endif

  if a:type =~ '^\u'
    " Reverse order.
    let files = reverse(files)
  endif

  return files
endfunction"}}}
function! s:compare_size(i1, i2)"{{{
  return a:i1.vimfiler__filesize > a:i2.vimfiler__filesize ? 1 : a:i1.vimfiler__filesize == a:i2.vimfiler__filesize ? 0 : -1
endfunction"}}}
function! s:compare_extension(i1, i2)"{{{
  return a:i1.vimfiler__extension > a:i2.vimfiler__extension ? 1 : a:i1.vimfiler__extension == a:i2.vimfiler__extension ? 0 : -1
endfunction"}}}
function! s:compare_name(i1, i2)"{{{
  return a:i1.vimfiler__filename > a:i2.vimfiler__filename ? 1 : a:i1.vimfiler__filename == a:i2.vimfiler__filename ? 0 : -1
endfunction"}}}
function! s:compare_time(i1, i2)"{{{
  return a:i1.vimfiler__filetime > a:i2.vimfiler__filetime ? 1 : a:i1.vimfiler__filetime == a:i2.vimfiler__filetime ? 0 : -1
endfunction"}}}

" Complete.
function! vimfiler#complete(arglead, cmdline, cursorpos)"{{{
  let [source_name, source_arg] = vimfiler#parse_path(a:arglead)

  let _ = []

  " Scheme args completion.
  let _ += unite#vimfiler_complete([[source_name, source_arg]],
        \ source_arg, a:cmdline, a:cursorpos)

  if a:arglead !~ ':'
    " Scheme name completion.
    let _ += map(filter(unite#get_vimfiler_source_names(),
          \ 'stridx(v:val, a:arglead) == 0'), 'v:val.":"')
  else
    " Add "{source-name}:".
    let _  = map(_, 'source_name.":".v:val')
  endif

  return sort(_)
endfunction"}}}

" Event functions.
function! s:event_bufwin_enter()"{{{
  if !exists('b:vimfiler')
    return
  endif

  if bufwinnr(s:last_vimfiler_bufnr) > 0
        \ && s:last_vimfiler_bufnr != bufnr('%')
    let b:vimfiler.another_vimfiler_bufnr = s:last_vimfiler_bufnr
  endif

  if b:vimfiler.winwidth != winwidth(0)
    call vimfiler#redraw_screen()
  endif
endfunction"}}}
function! s:event_bufwin_leave()"{{{
  let s:last_vimfiler_bufnr = bufnr('%')
endfunction"}}}
function! s:restore_vimfiler()"{{{
  if !exists('b:vimfiler')
    return
  endif

  " Search other vimfiler window.
  let cnt = 1
  while cnt <= winnr('$')
    if cnt != winnr() && getwinvar(cnt, '&filetype') ==# 'vimfiler'
      return
    endif

    let cnt += 1
  endwhile

  " Restore another vimfiler.
  if bufnr('%') != b:vimfiler.another_vimfiler_bufnr
        \ && bufwinnr(b:vimfiler.another_vimfiler_bufnr) < 0
        \ && buflisted(b:vimfiler.another_vimfiler_bufnr) > 0
    call s:switch_vimfiler(b:vimfiler.another_vimfiler_bufnr,
          \ { 'is_split' : 1 }, '')
    wincmd p
    call vimfiler#redraw_screen()
  endif
endfunction"}}}

function! s:switch_vimfiler(bufnr, context, directory)"{{{
  if a:context.is_split
    execute 'vertical sbuffer' . a:bufnr
  else
    execute 'buffer' . a:bufnr
  endif

  " Set current directory.
  if a:directory != ''
    let b:vimfiler.current_dir =
          \ vimfiler#util#substitute_path_separator(a:directory)
    if b:vimfiler.current_dir !~ '/$'
      let b:vimfiler.current_dir .= '/'
    endif
  endif

  call vimfiler#force_redraw_screen()
endfunction"}}}

" vim: foldmethod=marker
