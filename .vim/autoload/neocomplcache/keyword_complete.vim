"=============================================================================
" FILE: keyword_complete.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 27 Mar 2009
" Usage: Just source this file.
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
" Version: 2.10, for Vim 7.0
"=============================================================================

function! neocomplcache#keyword_complete#get_keyword_list()"{{{
    " Check dictionaries and tags are exists.
    if !empty(&filetype) && has_key(g:NeoComplCache_DictionaryFileTypeLists, &filetype)
        let l:ft_dict = '^' . &filetype
    elseif !empty(g:NeoComplCache_DictionaryFileTypeLists['default'])
        let l:ft_dict = '^default'
    else
        " Dummy pattern.
        let l:ft_dict = '^$'
    endif

    if has_key(g:NeoComplCache_TagsLists, tabpagenr())
        let l:gtags = '^tags:' . tabpagenr()
    elseif !empty(g:NeoComplCache_TagsLists['default'])
        let l:gtags = '^tags:default'
    else
        " Dummy pattern.
        let l:gtags = '^$'
    endif
    if &buftype !~ 'nofile'
        let l:ltags = printf('ltags:,%s', expand('%:p:h') . '/tags')
    else
        " Dummy pattern.
        let l:ltags = '^$'
    endif

    if has_key(g:NeoComplCache_DictionaryBufferLists, bufnr('%'))
        let l:buf_dict = '^dict:' . bufnr('%')
    else
        " Dummy pattern.
        let l:buf_dict = '^$'
    endif

    if g:NeoComplCache_EnableMFU
        let l:mfu_dict = '^mfu:' . &filetype
    else
        " Dummy pattern.
        let l:mfu_dict = '^$'
    endif

    " Set buffer filetype.
    if empty(&filetype)
        let l:ft = 'nothing'
    else
        let l:ft = &filetype
    endif

    let l:keyword_list = []
    for key in keys(s:source)
        if (key =~ '^\d' && l:ft == s:source[key].filetype)
                    \|| key =~ l:ft_dict || key == l:ltags || key =~ l:mfu_dict || key =~ l:gtags || key =~ l:buf_dict 
            call extend(l:keyword_list, values(s:source[key].keyword_cache))
        endif
    endfor

    let l:ft_list = []
    " Set same filetype.
    if has_key(g:NeoComplCache_SameFileTypeLists, l:ft)
        call extend(l:ft_list, split(g:NeoComplCache_SameFileTypeLists[&filetype], ','))
    endif

    " Set compound filetype.
    if l:ft =~ '\.'
        call extend(l:ft_list, split(l:ft, '\.'))
    endif

    for l:t in l:ft_list
        if g:NeoComplCache_EnableMFU
            let l:mfu_dict = '^mfu:' . l:t
        else
            " Dummy pattern.
            let l:mfu_dict = '^$'
        endif
        if !empty(l:t) && has_key(g:NeoComplCache_DictionaryFileTypeLists, l:t)
            let l:ft_dict = '^' . l:t
        else
            " Dummy pattern.
            let l:ft_dict = '^$'
        endif

        for key in keys(s:source)
            if key =~ '^\d' && l:t == s:source[key].filetype
                        \|| key =~ l:ft_dict || key =~ l:mfu_dict 
                call extend(l:keyword_list, values(s:source[key].keyword_cache))
            endif
        endfor
    endfor

    return l:keyword_list
endfunction"}}}

function! neocomplcache#keyword_complete#calc_rank(cache_keyword_buffer_list)"{{{
    let l:list_len = len(a:cache_keyword_buffer_list)

    if l:list_len > g:NeoComplCache_CalcRankMaxLists
        let l:calc_cnt = 5
    elseif l:list_len > g:NeoComplCache_CalcRankMaxLists / 2
        let l:calc_cnt = 4
    elseif l:list_len > g:NeoComplCache_CalcRankMaxLists / 4
        let l:calc_cnt = 3
    else
        let l:calc_cnt = 2
    endif

    if g:NeoComplCache_CalcRankRandomize
        let l:match_end = matchend(reltimestr(reltime()), '\d\+\.') + 1
    endif

    for keyword in a:cache_keyword_buffer_list
        if !has_key(keyword, 'rank') || s:rank_cache_count <= 0
            " Reset count.
            if g:NeoComplCache_CalcRankRandomize
                let [s:rank_cache_count, keyword.rank] = [reltimestr(reltime())[l:match_end : ] % l:calc_cnt, 0]
            else 
                let [s:rank_cache_count, keyword.rank] = [l:calc_cnt, 0]
            endif

            " Set rank.
            for keyword_lines in values(s:source[keyword.srcname].rank_cache_lines)
                if has_key(keyword_lines, keyword.word)
                    let keyword.rank += keyword_lines[keyword.word]
                endif
            endfor

            if g:NeoComplCache_EnableInfo
                " Create info.
                let keyword.info = join(keyword.info_list, "\n")
            endif
        else
            let s:rank_cache_count -= 1
        endif
    endfor
endfunction"}}}

function! neocomplcache#keyword_complete#exists_current_source()"{{{
    return has_key(s:source, bufnr('%'))
endfunction"}}}

function! neocomplcache#keyword_complete#current_keyword_pattern()"{{{
    return s:source[bufnr('%')].keyword_pattern
endfunction"}}}

function! neocomplcache#keyword_complete#caching(srcname, start_line, end_line)"{{{
    let l:start_line = (a:start_line == '%')? line('.') : a:start_line
    let l:start_line = (l:start_line-1)/g:NeoComplCache_CacheLineCount*g:NeoComplCache_CacheLineCount+1
    let l:end_line = (a:end_line < 0)? '$' : 
                \ (l:start_line + a:end_line + g:NeoComplCache_CacheLineCount-2)/g:NeoComplCache_CacheLineCount*g:NeoComplCache_CacheLineCount

    " Check exists s:source.
    if !has_key(s:source, a:srcname)
        " Initialize source.
        call s:initialize_source(a:srcname)
    elseif a:srcname =~ '^\d' && 
                \(s:source[a:srcname].name != fnamemodify(bufname(a:srcname), ':t')
                \||s:source[a:srcname].filetype != getbufvar(a:srcname, '&filetype'))
        " Initialize source if bufname changed.
        call s:initialize_source(a:srcname)
        let l:start_line = 1
        if a:end_line < 0
            " Whole buffer.
            let s:source[a:srcname].cached_last_line = s:source[a:srcname].end_line + 1
        else
            let s:source[a:srcname].cached_last_line = a:end_line
        endif
    endif

    let l:source = s:source[a:srcname]
    if a:srcname =~ '^\d'
        " Buffer.
        
        if empty(l:source.name)
            let l:filename = '[NoName]'
        else
            let l:filename = l:source.name
        endif
    else
        " Dictionary or tags.
        if a:srcname =~ '^tags:' || a:srcname =~ '^ltags:' 
            let l:prefix = '[T] '
        elseif a:srcname =~ '^dict:'
            let l:prefix = '[B] '
        elseif a:srcname =~ '^mfu:'
            let l:prefix = '[M] '
        else
            let l:prefix = '[F] '
        endif
        let l:filename = l:prefix . fnamemodify(l:source.name, ':t')
    endif
    let l:cache_line = (l:start_line-1) / g:NeoComplCache_CacheLineCount
    let l:line_cnt = 0

    " For debugging.
    "if l:end_line == '$'
        "echomsg printf("%s: start=%d, end=%d", l:filename, l:start_line, l:source.end_line)
    "else
        "echomsg printf("%s: start=%d, end=%d", l:filename, l:start_line, l:end_line)
    "endif

    if a:start_line == 1 && a:end_line < 0
        " Cache clear if whole buffer.
        let l:source.keyword_cache = {}
        let l:source.rank_cache_lines = {}
    endif

    " Clear cache line.
    let l:source.rank_cache_lines[l:cache_line] = {}

    if a:srcname =~ '^\d'
        " Buffer.
        let l:buflines = getbufline(a:srcname, l:start_line, l:end_line)
    else
        if l:end_line == '$'
            let l:end_line = l:source.end_line
        endif
        " Dictionary or tags.
        let l:buflines = readfile(l:source.name)[l:start_line : l:end_line]
    endif
    let l:menu = printf(' %.' . g:NeoComplCache_MaxFilenameWidth . 's', l:filename)
    let l:abbr_pattern = printf('%%.%ds..%%s', g:NeoComplCache_MaxKeywordWidth-10)
    let l:keyword_pattern = l:source.keyword_pattern

    let [l:max_line, l:line_num] = [len(l:buflines), 0]
    while l:line_num < l:max_line
        if l:line_cnt >= g:NeoComplCache_CacheLineCount
            " Next cache line.
            let l:cache_line += 1
            let l:source.rank_cache_lines[l:cache_line] = {}
            let l:line_cnt = 0
        endif

        let l:line = buflines[l:line_num]
        let [l:match_num, l:match_end, l:prev_word, l:prepre_word, l:info_line] =
                    \[match(l:line, l:keyword_pattern), matchend(l:line, l:keyword_pattern), '', '', 
                    \substitute(l:line, '^\s\+', '', '')[:100]]
        while l:match_num >= 0
            let l:match_str = matchstr(l:line, l:keyword_pattern, l:match_num)

            " Ignore too short keyword.
            if len(l:match_str) >= g:NeoComplCache_MinKeywordLength
                if !has_key(l:source.rank_cache_lines[l:cache_line], l:match_str) 
                    let l:source.rank_cache_lines[l:cache_line][l:match_str] = 1

                    " Check dup.
                    if !has_key(l:source.keyword_cache, l:match_str)
                        " Append list.
                        let l:source.keyword_cache[l:match_str] = {
                                    \'word' : l:match_str, 'menu' : l:menu,  'dup' : 0,
                                    \'filename' : l:filename, 'srcname' : a:srcname, 'prev_word' : {}, 'prepre_word' : {},
                                    \'info_list' : [l:info_line] }

                        if len(l:match_str) > g:NeoComplCache_MaxKeywordWidth
                            let l:source.keyword_cache[l:match_str].abbr = printf(l:abbr_pattern, l:match_str, l:match_str[-8:])
                        else
                            let l:source.keyword_cache[l:match_str].abbr = l:match_str
                        endif
                    endif
                else
                    let l:source.rank_cache_lines[l:cache_line][l:match_str] += 1

                    if len(l:source.keyword_cache[l:match_str].info_list) < g:NeoComplCache_MaxInfoList
                        cal add(l:source.keyword_cache[l:match_str].info_list, l:info_line)
                    endif
                endif

                let l:keyword_match = l:source.keyword_cache[l:match_str]

                " Save previous keyword.
                if !empty(l:prev_word) || l:line !~ '^\$\s'
                    if empty(l:prev_word)
                        let l:prev_word = '^'
                    else
                        if empty(l:prepre_word)
                            let l:prepre_word = '^'
                        endif
                        let l:keyword_match.prepre_word[l:prepre_word] = 1
                    endif
                    let l:keyword_match.prev_word[l:prev_word] = 1
                endif
            endif

            " Next match.
            let [l:match_num, l:match_end, l:prev_word, l:prepre_word] =
                        \[l:match_end, matchend(l:line, l:keyword_pattern, l:match_end), l:match_str, l:prev_word]
        endwhile

        let l:line_num += 1
        let l:line_cnt += 1
    endwhile
endfunction"}}}

function! s:initialize_source(srcname)"{{{
    if a:srcname =~ '^\d'
        " Buffer.
        let l:filename = fnamemodify(bufname(a:srcname), ':t')

        if a:srcname == bufnr('%')
            " Current buffer.
            let l:end_line = line('$')
        else
            let l:end_line = len(getbufline(a:srcname, 1, '$'))
        endif

        let l:ft = getbufvar(a:srcname, '&filetype')
        if empty(l:ft)
            let l:ft = 'nothing'
        endif

        if l:ft =~ '\.'
            " Composite filetypes.
            let l:keyword_array = []
            let l:keyword_default = 0
            for l:f in split(l:ft, '\.')
                if !has_key(g:NeoComplCache_KeywordPatterns, l:ft)
                    if !l:keyword_default
                        " Assuming failed.
                        call add(l:keyword_array, g:NeoComplCache_KeywordPatterns['default'])
                        let l:keyword_default = 1
                    endif
                else
                    call add(l:keyword_array, g:NeoComplCache_KeywordPatterns[l:f])
                endif
            endfor
            let l:keyword_pattern = '\(' . join(l:keyword_array, '\|') . '\)'
        else
            " Normal filetypes.
            if !has_key(g:NeoComplCache_KeywordPatterns, l:ft)
                let l:keyword_pattern = neocomplcache#assume_pattern(l:filename)
                if empty(l:keyword_pattern)
                    " Assuming failed.
                    let l:keyword_pattern = g:NeoComplCache_KeywordPatterns['default']
                endif
            else
                let l:keyword_pattern = g:NeoComplCache_KeywordPatterns[l:ft]
            endif
        endif
    else
        " Dictionary or tags.
        let l:filename = split(a:srcname, ',')[1]
        let l:end_line = len(readfile(l:filename))

        " Assuming filetype.
        if a:srcname =~ '^tags:' || a:srcname =~ '^ltags:' || a:srcname =~ '^dict:'
            " Current buffer filetype.
            let l:ft = &filetype
        elseif a:srcname =~ '^mfu:'
            " Embeded filetype.
            let l:ft = substitute(split(a:srcname, ',')[0], '^mfu:', '', '')
        else
            " Embeded filetype.
            let l:ft = split(a:srcname, ',')[0]
        endif

        let l:keyword_pattern = neocomplcache#assume_pattern(l:filename)
        if empty(l:keyword_pattern)
            " Assuming failed.
            let l:keyword_pattern = has_key(g:NeoComplCache_KeywordPatterns, l:ft)? 
                        \g:NeoComplCache_KeywordPatterns[l:ft] : g:NeoComplCache_KeywordPatterns['default']
        endif
    endif

    let s:source[a:srcname] = { 'keyword_cache' : {}, 'rank_cache_lines' : {},
                \'name' : l:filename, 'filetype' : l:ft, 'keyword_pattern' : l:keyword_pattern, 
                \'end_line' : l:end_line , 'cached_last_line' : 1 }
endfunction"}}}

function! s:caching_source(srcname, start_line, end_line)"{{{
    if !has_key(s:source, a:srcname)
        " Initialize source.
        call s:initialize_source(a:srcname)
    endif

    if a:start_line == '^'
        let l:source = s:source[a:srcname]

        let l:start_line = l:source.cached_last_line
        " Check overflow.
        if l:start_line > l:source.end_line && a:srcname =~ '^\d'
                    \&& fnamemodify(bufname(a:srcname), ':t') == l:source.name
            " Caching end.
            return -1
        endif

        let l:source.cached_last_line += a:end_line
    else
        let l:start_line = a:start_line
    endif

    call neocomplcache#keyword_complete#caching(a:srcname, l:start_line, a:end_line)

    return 0
endfunction"}}}

function! neocomplcache#keyword_complete#check_source(caching_num)"{{{
    let l:bufnumber = 1
    let l:max_buf = bufnr('$')
    let l:caching_num = 0

    let l:ft_dicts = []
    call add(l:ft_dicts, 'default')

    " Check deleted buffer.
    for key in keys(s:source)
        if key =~ '^\d' && !buflisted(str2nr(key))
            if g:NeoComplCache_EnableMFU
                " Save MFU.
                call s:save_MFU(key)
                return
            endif
            
            " Remove item.
            call remove(s:source, key)
        endif
    endfor

    " Check new buffer.
    while l:bufnumber <= l:max_buf
        if buflisted(l:bufnumber)
            if !has_key(s:source, l:bufnumber) ||
                        \getbufvar(l:bufnumber, '&filetype') != s:source[l:bufnumber].filetype
                " Caching.
                call s:caching_source(l:bufnumber, '^', a:caching_num)

                " Check buffer dictionary.
                if has_key(g:NeoComplCache_DictionaryBufferLists, l:bufnumber)
                    let l:dict_lists = split(g:NeoComplCache_DictionaryBufferLists[l:bufnumber], ',')
                    for dict in l:dict_lists
                        let l:dict_name = printf('dict:%s,%s', l:bufnumber, dict)
                        if !has_key(s:source, l:dict_name) && filereadable(dict)
                            " Caching.
                            call s:caching_source(l:dict_name, '^', a:caching_num)
                        endif
                    endfor
                endif

                " Check local tags.
                if &buftype !~ 'nofile'
                    let l:ltags = expand('#'.l:bufnumber.':p:h') . '/tags'
                    let l:ltags_dict = printf('ltags:,%s', l:ltags)
                    if filereadable(l:ltags) && !has_key(s:source, l:ltags_dict)
                        " Caching.
                        call s:caching_source(l:ltags_dict, '^', a:caching_num)

                        let s:source[l:bufnumber].ctagsed_lines = s:source[l:bufnumber].end_line
                    endif
                endif
            endif

            if has_key(g:NeoComplCache_DictionaryFileTypeLists, getbufvar(l:bufnumber, '&filetype'))
                call add(l:ft_dicts, getbufvar(l:bufnumber, '&filetype'))
            endif

            " Check MFU.
            if g:NeoComplCache_EnableMFU
                let l:mfu_path = printf('%s/%s.mfu', g:NeoComplCache_MFUDirectory, &filetype)
                if g:NeoComplCache_EnableMFU && filereadable(l:mfu_path) && getfsize(l:mfu_path) > 0
                    " Load MFU
                    let l:dict_name = printf('mfu:%s,%s', &filetype, l:mfu_path)
                    if !has_key(s:source, l:dict_name)
                        " Caching.
                        call s:caching_source(l:dict_name, '^', a:caching_num)
                    endif
                endif
            endif
        endif

        let l:bufnumber += 1
    endwhile

    " Check dictionary.
    for l:ft_dict in l:ft_dicts
        " Ignore if empty.
        if !empty(l:ft_dict)
            for dict in split(g:NeoComplCache_DictionaryFileTypeLists[l:ft_dict], ',')
                let l:dict_name = printf('%s,%s', l:ft_dict, dict)
                if !has_key(s:source, l:dict_name) && filereadable(dict)
                    " Caching.
                    call s:caching_source(l:dict_name, '^', a:caching_num)
                endif
            endfor
        endif
    endfor

    " Check global tags.
    let l:current_tags = (has_key(g:NeoComplCache_TagsLists, tabpagenr()))? tabpagenr() : 'default'
    " Ignore if empty.
    if !empty(l:current_tags)
        let l:tags_lists = split(g:NeoComplCache_TagsLists[l:current_tags], ',')
        for gtags in l:tags_lists
            let l:tags_name = printf('tags:%d,%s', l:current_tags, gtags)
            if !has_key(s:source, l:tags_name) && filereadable(gtags)
                " Caching.
                call s:caching_source(l:tags_name, '^', a:caching_num)
            endif
        endfor
    endif
endfunction"}}}
function! neocomplcache#keyword_complete#update_source(caching_num, caching_max)"{{{
    let l:caching_num = 0
    for source_name in keys(s:source)
        " Lazy caching.
        let name = (source_name =~ '^\d')? str2nr(source_name) : source_name

        if s:caching_source(name, '^', a:caching_num) == 0
            let l:caching_num += a:caching_num

            if l:caching_num > a:caching_max
                return
            endif
        endif
    endfor
endfunction"}}}

function! neocomplcache#keyword_complete#save_all_MFU()"{{{
    if !g:NeoComplCache_EnableMFU
        return
    endif

    for key in keys(s:source)
        if key =~ '^\d'
            call s:save_MFU(key)
        endif
    endfor
endfunction "}}}
function! s:save_MFU(key)"{{{
    let l:ft = getbufvar(str2nr(a:key), '&filetype')
    if empty(l:ft)
        return
    endif

    let l:mfu_dict = {}
    let l:prev_word = {}
    let l:prepre_word = {}
    let l:mfu_path = printf('%s/%s.mfu', g:NeoComplCache_MFUDirectory, l:ft)
    if filereadable(l:mfu_path)
        for line in readfile(l:mfu_path)
            let l = split(line)
            if len(l) == 3 
                if line =~ '^$ '
                    let l:mfu_dict[l[1]] = { 'word' : l[1], 'rank' : l[2], 'found' : 0 }
                else
                    if !has_key(l:prepre_word, l[2])
                        let l:prepre_word[l[2]] = {}
                    endif
                    let l:prepre_word[l[2]][l[0]] = 1
                endif
            elseif len(l) == 2
                if !has_key(l:prev_word, l[0])
                    let l:prev_word[l[0]] = {}
                endif
                let l:prev_word[l[0]][l[1]] = l[1]
            elseif len(l) == 1
                if !has_key(l:prev_word, l[0])
                    let l:prev_word[l[0]] = {}
                endif
                let l:prev_word[l[0]]['^'] = 1
            endif
        endfor
    endif
    for keyword in values(s:source[a:key].keyword_cache)
        if has_key(keyword, 'rank') && keyword.rank*2 >= g:NeoComplCache_MFUThreshold
            if !has_key(l:mfu_dict, keyword.word) || keyword.rank > l:mfu_dict[keyword.word].rank
                let l:mfu_dict[keyword.word] = { 'word' : keyword.word, 'rank' : keyword.rank*2, 'found' : 1 }
            endif

            if has_key(keyword, 'prev_word')
                let l:prev_word[keyword.word] = keyword.prev_word
            endif
            if has_key(keyword, 'prepre_word')
                let l:prepre_word[keyword.word] = keyword.prepre_word
            endif
        elseif has_key(l:mfu_dict, keyword.word)
            " Found.
            let l:mfu_dict[keyword.word].found = 1

            if has_key(keyword, 'prev_word')
                let l:prev_word[keyword.word] = keyword.prev_word
            endif
            if has_key(keyword, 'prepre_word')
                let l:prepre_word[keyword.word] = keyword.prepre_word
            endif
        endif
    endfor

    if s:source[a:key].end_line > 100
        " Reduce rank if word is not found.
        for key in keys(l:mfu_dict)
            if !l:mfu_dict[key].found
                " rank *= 0.9
                let l:mfu_dict[key].rank -= l:mfu_dict[key].rank / 10
                if l:mfu_dict[key].rank < g:NeoComplCache_MFUThreshold
                    " Delete word.
                    call remove(l:mfu_dict, key)
                    if has_key(l:prev_word, key)
                        call remove(l:prev_word, key)
                    endif
                    if has_key(l:prepre_word, key)
                        call remove(l:prepre_word, key)
                    endif
                endif
            endif
        endfor
    endif

    " Save MFU.
    let l:mfu_word = []
    for dict in sort(values(l:mfu_dict), 'neocomplcache#compare_rank')
        call add(l:mfu_word, printf('$ %s %s' , dict.word, dict.rank))
    endfor
    for prevs_key in keys(l:prev_word)
        for prev in keys(l:prev_word[prevs_key])
            if prev == '^' 
                call add(l:mfu_word, printf('%s', prevs_key))
            else
                call add(l:mfu_word, printf('%s %s', prev, prevs_key))
            endif
        endfor
    endfor
    for prevs_key in keys(l:prepre_word)
        for prev in keys(l:prepre_word[prevs_key])
            if prev == '^' 
                call add(l:mfu_word, printf('x %s', prevs_key))
            else
                call add(l:mfu_word, printf('%s x %s', prev, prevs_key))
            endif
        endfor
    endfor
    call writefile(l:mfu_word[: g:NeoComplCache_MFUMax-1], l:mfu_path)
endfunction "}}}

function! neocomplcache#keyword_complete#output_keyword(number)"{{{
    if empty(a:number)
        let l:number = bufnr('%')
    else
        let l:number = a:number
    endif

    if !has_key(s:source, l:number)
        return
    endif

    let l:keyword_dict = {}
    let l:prev_word = {}
    let l:prepre_word = {}
    for keyword in values(s:source[l:number].keyword_cache)
        if has_key(keyword, 'rank')
            let l:keyword_dict[keyword.word] = { 'word' : keyword.word, 'rank' : keyword.rank, }
        else
            let l:keyword_dict[keyword.word] = { 'word' : keyword.word, 'rank' : 0, }
        endif
        if has_key(keyword, 'prev_word')
            let l:prev_word[keyword.word] = keyword.prev_word
        endif
        if has_key(keyword, 'prepre_word')
            let l:prepre_word[keyword.word] = keyword.prepre_word
        endif
    endfor

    " Output buffer.
    let l:keywords = []
    for dict in sort(values(l:keyword_dict), 'neocomplcache#compare_rank')
        call add(l:keywords, printf('$ %s %s' , dict.word, dict.rank))
    endfor
    for prevs_key in keys(l:prev_word)
        for prev in keys(l:prev_word[prevs_key])
            if prev == '^' 
                call add(l:keywords, printf('%s', prevs_key))
            else
                call add(l:keywords, printf('%s %s', prev, prevs_key))
            endif
        endfor
    endfor
    for prevs_key in keys(l:prepre_word)
        for prev in keys(l:prepre_word[prevs_key])
            if prev == '^' 
                call add(l:keywords, printf('x %s', prevs_key))
            else
                call add(l:keywords, printf('%s x %s', prev, prevs_key))
            endif
        endfor
    endfor

    for l:word in l:keywords
        silent put=l:word
    endfor
endfunction "}}}

function! neocomplcache#keyword_complete#set_buffer_dictionary(files)"{{{
    let l:files = substitute(substitute(a:files, '\\\s', ';', 'g'), '\s\+', ',', 'g')
    silent execute printf("let g:NeoComplCache_DictionaryBufferLists[%d] = '%s'", 
                \bufnr('%') , substitute(l:files, ';', ' ', 'g'))
    " Caching.
    call neocomplcache#keyword_complete#check_source(g:NeoComplCache_CacheLineCount*10)
endfunction "}}}

function! neocomplcache#keyword_complete#initialize()"{{{
    augroup neocomplecache_keyword_complete"{{{
        autocmd!
        " Caching events
        autocmd BufEnter,BufWritePost,CursorHold * call neocomplcache#keyword_complete#update_source(g:NeoComplCache_CacheLineCount*10, 
                    \ g:NeoComplCache_CacheLineCount*30)
        autocmd BufAdd * call neocomplcache#keyword_complete#check_source(g:NeoComplCache_CacheLineCount*10)
        " Caching current buffer events
        autocmd InsertEnter,InsertLeave * call neocomplcache#keyword_complete#caching(bufnr('%'), '%', g:NeoComplCache_CacheLineCount)
        " MFU events.
        autocmd VimLeavePre * call neocomplcache#keyword_complete#save_all_MFU()
        " Garbage collect.
        autocmd BufWritePost * call neocomplcache#keyword_complete#garbage_collect()
    augroup END"}}}

    if g:NeoComplCache_TagsAutoUpdate
        augroup neocomplecache_keyword_complete
            autocmd BufWritePost * call neocomplcache#keyword_complete#update_tags()
        augroup END
    endif

    " Initialize"{{{
    let s:source = {}
    let s:rank_cache_count = 1
    "}}}
    
    " Initialize dictionary and tags."{{{
    if !exists('g:NeoComplCache_DictionaryFileTypeLists')
        let g:NeoComplCache_DictionaryFileTypeLists = {}
    endif
    if !has_key(g:NeoComplCache_DictionaryFileTypeLists, 'default')
        let g:NeoComplCache_DictionaryFileTypeLists['default'] = ''
    endif
    if !exists('g:NeoComplCache_DictionaryBufferLists')
        let g:NeoComplCache_DictionaryBufferLists = {}
    endif
    if !exists('g:NeoComplCache_TagsLists')
        let g:NeoComplCache_TagsLists = {}
    endif
    if !has_key(g:NeoComplCache_TagsLists, 'default')
        let g:NeoComplCache_TagsLists['default'] = ''
    endif
    " For test.
    "let g:NeoComplCache_DictionaryFileTypeLists['vim'] = 'CSApprox.vim,LargeFile.vim'
    "let g:NeoComplCache_TagsLists[1] = 'tags,'.$DOTVIM.'\doc\tags'
    "let g:NeoComplCache_DictionaryBufferLists[1] = '256colors2.pl'"}}}
    
    " Add commands."{{{
    command! -nargs=? NeoCompleCacheCachingBuffer call neocomplcache#keyword_complete#caching_buffer(<q-args>)
    command! -nargs=0 NeoCompleCacheCachingTags call neocomplcache#keyword_complete#caching_tags()
    command! -nargs=0 NeoCompleCacheCachingDictionary call neocomplcache#keyword_complete#caching_dictionary()
    command! -nargs=0 NeoCompleCacheSaveMFU call neocomplcache#keyword_complete#save_all_MFU()
    command! -nargs=* -complete=file NeoCompleCacheSetBufferDictionary call neocomplcache#keyword_complete#set_buffer_dictionary(<q-args>)
    command! -nargs=? NeoCompleCachePrintSource call neocomplcache#keyword_complete#print_source(<q-args>)
    command! -nargs=? NeoCompleCacheOutputKeyword call neocomplcache#keyword_complete#output_keyword(<q-args>)
    command! -nargs=? NeoCompleCacheCreateTags call neocomplcache#keyword_complete#create_tags()
    "}}}
    
    " Initialize ctags arguments.
    if !exists('g:NeoComplCache_CtagsArgumentsList')
        let g:NeoComplCache_CtagsArgumentsList = {}
    endif
    let g:NeoComplCache_CtagsArgumentsList['default'] = ''

    " Initialize cache.
    call neocomplcache#keyword_complete#check_source(g:NeoComplCache_CacheLineCount*10)
endfunction"}}}

function! neocomplcache#keyword_complete#finalize()"{{{
    augroup neocomplecache_keyword_complete
        autocmd!
    augroup END

    delcommand NeoCompleCacheCachingBuffer
    delcommand NeoCompleCacheCachingTags
    delcommand NeoCompleCacheCachingDictionary
    delcommand NeoCompleCacheSaveMFU
    delcommand NeoCompleCacheSetBufferDictionary
    delcommand NeoCompleCachePrintSource
    delcommand NeoCompleCacheOutputKeyword
    delcommand NeoCompleCacheCreateTags
endfunction"}}}

function! neocomplcache#keyword_complete#caching_buffer(number)"{{{
    if empty(a:number)
        let l:number = bufnr('%')
    else
        let l:number = a:number
    endif
    call s:caching_source(l:number, 1, -1)

    " Disable auto caching.
    let s:source[l:number].cached_last_line = s:source[l:number].end_line+1

    " Calc rank.
    call neocomplcache#get_complete_words('')
endfunction"}}}

function! neocomplcache#keyword_complete#caching_tags()"{{{
    " Create source.
    call neocomplcache#keyword_complete#check_source(g:NeoComplCache_CacheLineCount*10)
    
    " Check tags are exists.
    if has_key(g:NeoComplCache_TagsLists, tabpagenr())
        let l:gtags = '^tags:' . tabpagenr()
    elseif !empty(g:NeoComplCache_TagsLists['default'])
        let l:gtags = '^tags:default'
    else
        " Dummy pattern.
        let l:gtags = '^$'
    endif
    let l:ltags = printf('ltags:,%s', expand('%:p:h') . '/tags')

    let l:cache_keyword_buffer_filtered = []
    for key in keys(s:source)
        if key =~ l:gtags || key == l:ltags
            call s:caching_source(key, '^', -1)

            " Disable auto caching.
            let s:source[key].cached_last_line = s:source[key].end_line+1
        endif
    endfor
endfunction"}}}

function! neocomplcache#keyword_complete#caching_dictionary()"{{{
    " Create source.
    call neocomplcache#keyword_complete#check_source(g:NeoComplCache_CacheLineCount*10)

    " Check dictionaries are exists.
    if !empty(&filetype) && has_key(g:NeoComplCache_DictionaryFileTypeLists, &filetype)
        let l:ft_dict = '^' . &filetype
    elseif !empty(g:NeoComplCache_DictionaryFileTypeLists['default'])
        let l:ft_dict = '^default'
    else
        " Dummy pattern.
        let l:ft_dict = '^$'
    endif
    if has_key(g:NeoComplCache_DictionaryBufferLists, bufnr('%'))
        let l:buf_dict = '^dict:' . bufnr('%')
    else
        " Dummy pattern.
        let l:buf_dict = '^$'
    endif
    if g:NeoComplCache_EnableMFU
        let l:mfu_dict = '^mfu:' . &filetype
    else
        " Dummy pattern.
        let l:mfu_dict = '^$'
    endif
    let l:cache_keyword_buffer_filtered = []
    for key in keys(s:source)
        if key =~ l:ft_dict || key =~ l:buf_dict || key =~ l:mfu_dict
            call s:caching_source(key, '^', -1)

            " Disable auto caching.
            let s:source[key].cached_last_line = s:source[key].end_line+1
        endif
    endfor
endfunction"}}}

function! neocomplcache#keyword_complete#update_tags()"{{{
    " Check tags are exists.
    if !has_key(s:source, bufnr('%')) || !has_key(s:source[bufnr('%')], 'ctagsed_lines')
        return
    endif

    let l:max_line = line('$')
    if abs(l:max_line - s:source[bufnr('%')].ctagsed_lines) > l:max_line / 20
        if has_key(g:NeoComplCache_CtagsArgumentsList, &filetype)
            let l:args = g:NeoComplCache_CtagsArgumentsList[&filetype]
        else
            let l:args = g:NeoComplCache_CtagsArgumentsList['default']
        endif
        call system(printf('ctags -f %s %s -a %s', expand('%:p:h') . '/tags', l:args, expand('%')))
        let s:source[bufnr('%')].ctagsed_lines = l:max_line
    endif
endfunction"}}}

function! neocomplcache#keyword_complete#create_tags()"{{{
    if &buftype =~ 'nofile' || !neocomplcache#keyword_complete#exists_current_source()
        return
    endif

    " Create tags.
    if has_key(g:NeoComplCache_CtagsArgumentsList, &filetype)
        let l:args = g:NeoComplCache_CtagsArgumentsList[&filetype]
    else
        let l:args = g:NeoComplCache_CtagsArgumentsList['default']
    endif

    let l:ltags = expand('%:p:h') . '/tags'
    call system(printf('ctags -f %s %s -a %s', expand('%:h') . '/tags', l:args, expand('%')))
    let s:source[bufnr('%')].ctagsed_lines = line('$')

    " Check local tags.
    let l:ltags_dict = printf('ltags:,%s', l:ltags)
    if !has_key(s:source, l:ltags_dict)
        " Caching.
        call s:caching_source(l:ltags_dict, '^', g:NeoComplCache_CacheLineCount*10)
    endif
endfunction"}}}

function! neocomplcache#keyword_complete#garbage_collect()"{{{
    if !neocomplcache#keyword_complete#exists_current_source()
        return
    endif
    
    let l:source = s:source[bufnr('%')].keyword_cache
    for l:key in keys(l:source)
        if has_key(l:source[l:key], 'rank') && l:source[l:key].rank == 0
            " Delete keyword.
            call remove(l:source, l:key)
        endif
    endfor
endfunction"}}}

" For debug command.
function! neocomplcache#keyword_complete#print_source(number)"{{{
    if empty(a:number)
        let l:number = bufnr('%')
    else
        let l:number = a:number
    endif

    silent put=printf('Print neocomplcache %d source.', l:number)
    for l:key in keys(s:source[l:number])
        silent put =printf('%s => %s', l:key, string(s:source[l:number][l:key]))
    endfor
endfunction"}}}

" vim: foldmethod=marker
