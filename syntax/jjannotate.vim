" Vim syntax file
" Language:	jj (Jujutsu) annotate output
" Maintainer:	Bob Hiestand <bob.hiestand@gmail.com>
" Remark:	Used by the vcscommand plugin.
" License:
" Copyright (c) Bob Hiestand
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
" FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
" IN THE SOFTWARE.
"
" Output format (one line per source line):
"   <8-char-change-id> <author> <date> <time>    <linenum>: <content>
" Example:
"   swtrsnou github.s 2026-03-23 18:43:41    1: line content

if exists("b:current_syntax")
	finish
endif

syn match jjChangeId /^\x\+/ contained
syn match jjAuthor /\s\+\S\+\ze\s\+\d\d\d\d-/ contained
syn match jjDate /\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/ contained
syn match jjLineNumber /\d\+\ze:/ contained
syn region jjAnnotation start="^" end=": " oneline keepend contains=jjChangeId,jjAuthor,jjDate,jjLineNumber

if !exists("did_jjannotate_syntax_inits")
	let did_jjannotate_syntax_inits = 1
	hi link jjChangeId Statement
	hi link jjAuthor Type
	hi link jjDate Comment
	hi link jjLineNumber Label
endif

let b:current_syntax="jjAnnotate"
