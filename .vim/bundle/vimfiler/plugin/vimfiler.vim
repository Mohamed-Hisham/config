"=============================================================================
" FILE: vimshell.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 17 Sep 2011.
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
"=============================================================================

if v:version < 700
  echoerr 'vimfiler does not work this version of Vim "' . v:version . '".'
  finish
elseif exists('g:loaded_vimfiler')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim
let s:iswin = has('win32') || has('win64')

" Global options definition."{{{
if !exists('g:vimfiler_as_default_explorer')
  let g:vimfiler_as_default_explorer = 0
endif
if !exists('g:vimfiler_execute_file_list')
  let g:vimfiler_execute_file_list = {}
endif
if !exists('g:vimfiler_split_action')
  let g:vimfiler_split_action = 'vsplit'
endif
if !exists('g:vimfiler_edit_action')
  let g:vimfiler_edit_action = 'open'
endif
if !exists('g:vimfiler_preview_action')
  let g:vimfiler_preview_action = 'preview'
endif
if !exists('g:vimfiler_min_filename_width')
  let g:vimfiler_min_filename_width = 30
endif
if !exists('g:vimfiler_max_filename_width')
  let g:vimfiler_max_filename_width = 80
endif
if !exists('g:vimfiler_sort_type')
  let g:vimfiler_sort_type = 'filename'
endif
if !exists('g:vimfiler_directory_display_top')
  let g:vimfiler_directory_display_top = 1
endif
if !exists('g:vimfiler_detect_drives')
  let g:vimfiler_detect_drives = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 
            \ 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S',
            \ 'T', 'U', 'V', 'W', 'X', 'Y', 'Z']
endif

if !exists('g:vimfiler_max_directories_history')
  let g:vimfiler_max_directories_history = 10
endif
if !exists('g:vimfiler_enable_clipboard')
  let g:vimfiler_enable_clipboard = 0
endif
if !exists('g:vimfiler_wildignore')
    let g:vimfiler_wildignore = &l:wildignore
endif
if !exists('g:vimfiler_safe_mode_by_default')
  let g:vimfiler_safe_mode_by_default = 1
endif
if !exists('g:vimfiler_time_format')
  let g:vimfiler_time_format = '%y/%m/%d %H:%M'
endif

" Set extensions.
if !exists('g:vimfiler_extensions')
  let g:vimfiler_extensions = {}
endif
if !has_key(g:vimfiler_extensions, 'text')
  call vimfiler#set_extensions('text', 'txt,cfg,ini')
endif
if !has_key(g:vimfiler_extensions, 'image')
  call vimfiler#set_extensions('image', 'bmp,png,gif,jpg,jpeg,jp2,tif,ico,wdp,cur,ani')
endif
if !has_key(g:vimfiler_extensions, 'archive')
  call vimfiler#set_extensions('archive', 'lzh,zip,gz,bz2,cab,rar,7z,tgz,tar')
endif
if !has_key(g:vimfiler_extensions, 'system')
  call vimfiler#set_extensions('system', 'inf,sys,reg,dat,spi,a,so,lib,dll')
endif
if !has_key(g:vimfiler_extensions, 'multimedia')
  call vimfiler#set_extensions('multimedia', 'avi,asf,wmv,mpg,flv,swf,divx,mov,mpa,m1a,m2p,m2a,mpeg,m1v,m2v,mp2v,mp4,qt,ra,rm,ram,rmvb,rpm,smi,mkv,mid,wav,mp3,ogg,wma,au')
endif
"}}}

" Plugin keymappings"{{{
nnoremap <silent> <Plug>(vimfiler_split_switch)
      \ :<C-u>call vimfiler#switch_filer('', { 'is_split' : 1 })<CR>
nnoremap <silent> <Plug>(vimfiler_split_create)
      \ :<C-u>call vimfiler#create_filer('', { 'is_split' : 1 })<CR>
nnoremap <silent> <Plug>(vimfiler_switch)
      \ :<C-u>call vimfiler#switch_filer('')<CR>
nnoremap <silent> <Plug>(vimfiler_create)
      \ :<C-u>call vimfiler#create_filer('')<CR>
nnoremap <silent> <Plug>(vimfiler_simple)
      \ :<C-u>call vimfiler#create_filer('', {'is_simple' : 1, 'split' : 1})<CR>
"}}}

command! -nargs=? -complete=customlist,vimfiler#complete VimFiler
      \ call vimfiler#switch_filer(<q-args>)
command! -nargs=? -complete=customlist,vimfiler#complete VimFilerDouble
      \ call vimfiler#create_filer(<q-args>,
      \   { 'is_double' : 1 })
command! -nargs=? -complete=customlist,vimfiler#complete VimFilerCreate
      \ call vimfiler#create_filer(<q-args>)
command! -nargs=? -complete=customlist,vimfiler#complete VimFilerSimple
      \ call vimfiler#create_filer(<q-args>,
      \   { 'is_simple' : 1, 'is_split' : 1 })
command! -nargs=? -complete=customlist,vimfiler#complete VimFilerSplit
      \ call vimfiler#create_filer(<q-args>,
      \   { 'is_split' : 1 })
command! -nargs=? -complete=customlist,vimfiler#complete VimFilerTab
      \ tabnew | call vimfiler#create_filer(<q-args>)
command! VimFilerDetectDrives call vimfiler#detect_drives()

if g:vimfiler_as_default_explorer
  augroup vimfiler-FileExplorer
    autocmd!
    autocmd BufEnter * call s:browse_check(expand('<amatch>'))
    autocmd BufReadCmd ??*:{*,*/*}  call vimfiler#handler#_event_handler('BufReadCmd')
    autocmd BufWriteCmd ??*:{*,*/*}  call vimfiler#handler#_event_handler('BufWriteCmd')
    autocmd FileAppendCmd ??*:{*,*/*}  call vimfiler#handler#_event_handler('FileAppendCmd')
    autocmd FileReadCmd ??*:{*,*/*}  call vimfiler#handler#_event_handler('FileReadCmd')
  augroup END

  " Define wrapper commands.
  command! -bang -bar -complete=customlist,vimfiler#complete -nargs=*
        \ Edit  edit<bang> <args>
  command! -bang -bar -complete=customlist,vimfiler#complete -nargs=*
        \ Read  read<bang> <args>
  command! -bang -bar -complete=customlist,vimfiler#complete -nargs=1
        \ Source  source<bang> <args>
  command! -bang -bar -complete=customlist,vimfiler#complete -nargs=* -range=%
        \ Write  <line1>,<line2>write<bang> <args>

  " Disable netrw.
  augroup FileExplorer
    autocmd!
  augroup END
endif

function! s:browse_check(path)
  " Disable netrw.
  augroup FileExplorer
    autocmd!
  augroup END

  if isdirectory(a:path) && &filetype != 'vimfiler'
    call vimfiler#handler#_event_handler('BufReadCmd')
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_vimfiler = 1

" vim: foldmethod=marker
