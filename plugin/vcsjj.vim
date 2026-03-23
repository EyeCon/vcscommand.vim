" vim600: set foldmethod=marker:
"
" jj (Jujutsu) extension for VCSCommand.
"
" Maintainer:    Bob Hiestand <bob.hiestand@gmail.com>
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
" Section: Documentation {{{1
"
" Options documentation: {{{2
"
" VCSCommandJJExec
"   This variable specifies the jj executable.  If not set, it defaults to
"   'jj' executed from the user's executable path.
"
" VCSCommandJJDiffOpt
"   This variable, if set, determines the default options passed to the
"   VCSDiff command.  If any options (starting with '-') are passed to the
"   command, this variable is not used.

" Section: Plugin header {{{1

if exists('VCSCommandDisableAll')
	finish
endif

if !exists('g:loaded_VCSCommand')
	runtime plugin/vcscommand.vim
endif

if !executable(VCSCommandGetOption('VCSCommandJJExec', 'jj'))
	" jj is not installed
	finish
endif

let s:save_cpo=&cpo
set cpo&vim

" Section: Variable initialization {{{1

let s:jjFunctions = {}

" Section: Utility functions {{{1

" Function: s:Executable() {{{2
" Returns the executable used to invoke jj suitable for use in a shell
" command.
function! s:Executable()
	return shellescape(VCSCommandGetOption('VCSCommandJJExec', 'jj'))
endfunction

" Function: s:DoCommand(cmd, cmdName, statusText, options) {{{2
" Wrapper to VCSCommandDoCommand to add the name of the jj executable to the
" command argument.
function! s:DoCommand(cmd, cmdName, statusText, options)
	if VCSCommandGetVCSType(expand('%')) == 'jj'
		let fullCmd = s:Executable() . ' ' . a:cmd
		return VCSCommandDoCommand(fullCmd, a:cmdName, a:statusText, a:options)
	else
		throw 'jj VCSCommand plugin called on non-jj item.'
	endif
endfunction

" Section: VCS function implementations {{{1

" Function: s:jjFunctions.Identify(buffer) {{{2
" Returns an exact match when the file is inside a jj repository, so that jj
" takes priority over git in colocated (git-backed) repositories.
function! s:jjFunctions.Identify(buffer)
	let oldCwd = VCSCommandChangeToCurrentFileDir(resolve(bufname(a:buffer)))
	try
		call s:VCSCommandUtility.system(s:Executable() . ' root')
		if(v:shell_error)
			return 0
		else
			return g:VCSCOMMAND_IDENTIFY_EXACT
		endif
	finally
		call VCSCommandChdir(oldCwd)
	endtry
endfunction

" Function: s:jjFunctions.Add(argList) {{{2
" Explicitly tracks previously-untracked files.  Modified files are tracked
" automatically by jj; this command is only needed for new untracked files.
function! s:jjFunctions.Add(argList)
	return s:DoCommand(join(['file', 'track'] + a:argList, ' '), 'add', join(a:argList, ' '), {})
endfunction

" Function: s:jjFunctions.Annotate(argList) {{{2
function! s:jjFunctions.Annotate(argList)
	if len(a:argList) == 0
		if &filetype == 'jjannotate'
			" Re-annotate: use the change ID on the current line as the revision.
			let options = '-r ' . matchstr(getline('.'), '^\x\+')
		else
			let options = ''
		endif
	elseif len(a:argList) == 1 && a:argList[0] !~ '^-'
		let options = '-r ' . a:argList[0]
	else
		let options = join(a:argList, ' ')
	endif

	return s:DoCommand('file annotate ' . options . ' <VCSCOMMANDFILE>', 'annotate', options, {})
endfunction

" Function: s:jjFunctions.Commit(argList) {{{2
" Creates a new change on top of the current one, equivalent to git commit.
function! s:jjFunctions.Commit(argList)
	try
		return s:DoCommand('commit -F "' . a:argList[0] . '"', 'commit', '', {})
	catch /\m^Version control command failed.*nothing changed/
		echomsg 'No commit needed.'
	endtry
endfunction

" Function: s:jjFunctions.Delete(argList) {{{2
" Stops tracking the current file in jj.  jj detects file deletions
" automatically, so this command is used to explicitly untrack a file.
function! s:jjFunctions.Delete(argList)
	return s:DoCommand(join(['file', 'untrack'] + a:argList, ' '), 'delete', join(a:argList, ' '), {})
endfunction

" Function: s:jjFunctions.Diff(argList) {{{2
" Pass-through call to jj diff.  If no options (starting with '-') are found,
" then the options in the 'VCSCommandJJDiffOpt' variable are added.
function! s:jjFunctions.Diff(argList)
	let jjDiffOpt = VCSCommandGetOption('VCSCommandJJDiffOpt', '')
	if jjDiffOpt == ''
		let diffOptions = []
	else
		let diffOptions = [jjDiffOpt]
		for arg in a:argList
			if arg =~ '^-'
				let diffOptions = []
				break
			endif
		endfor
	endif

	return s:DoCommand(join(['diff'] + diffOptions + a:argList), 'diff', join(a:argList), {})
endfunction

" Function: s:jjFunctions.GetBufferInfo() {{{2
" Provides version control details for the current file.  Returns a list of
" [change_id, bookmarks] where bookmarks may be absent.
function! s:jjFunctions.GetBufferInfo()
	let oldCwd = VCSCommandChangeToCurrentFileDir(resolve(bufname('%')))
	try
		let changeId = substitute(
				\ s:VCSCommandUtility.system(s:Executable() . ' log -r @ --no-graph -T "change_id.short()"'),
				\ '\n$', '', '')
		if v:shell_error
			return []
		endif

		let bookmarks = substitute(
				\ s:VCSCommandUtility.system(s:Executable() . ' log -r @ --no-graph -T "if(bookmarks, bookmarks.join(\", \"), \"\")"'),
				\ '\n$', '', '')

		if bookmarks != '' && !v:shell_error
			return [changeId, bookmarks]
		else
			return [changeId]
		endif
	finally
		call VCSCommandChdir(oldCwd)
	endtry
endfunction

" Function: s:jjFunctions.Log(argList) {{{2
function! s:jjFunctions.Log(argList)
	return s:DoCommand(join(['log'] + a:argList), 'log', join(a:argList, ' '), {})
endfunction

" Function: s:jjFunctions.Revert(argList) {{{2
" Restores the current file to the version in the parent revision.
function! s:jjFunctions.Revert(argList)
	return s:DoCommand('restore <VCSCOMMANDFILE>', 'revert', '', {})
endfunction

" Function: s:jjFunctions.Review(argList) {{{2
" Shows the file content at a specific revision.  Defaults to the working copy
" parent (@-).
function! s:jjFunctions.Review(argList)
	if len(a:argList) == 0
		let revision = '@-'
	else
		let revision = a:argList[0]
	endif

	return s:DoCommand('file show -r ' . revision . ' <VCSCOMMANDFILE>', 'review', revision, {})
endfunction

" Function: s:jjFunctions.Status(argList) {{{2
function! s:jjFunctions.Status(argList)
	return s:DoCommand(join(['status'] + a:argList), 'status', join(a:argList), {'allowNonZeroExit': 1})
endfunction

" Function: s:jjFunctions.Update(argList) {{{2
function! s:jjFunctions.Update(argList)
	throw "This command is not implemented for jj because per-file update doesn't apply in that context."
endfunction

" Annotate setting {{{2
" Output format: '<8-char-id> <author> <date> <time>    <linenum>: <content>'
" The regex splits at the padded line number field.
let s:jjFunctions.AnnotateSplitRegex = '\s\+\d\+: '

" Section: Plugin Registration {{{1
let s:VCSCommandUtility = VCSCommandRegisterModule('jj', expand('<sfile>'), s:jjFunctions, [])

let &cpo = s:save_cpo
