" Filename:      spacepaste.vim
" Description:   Vim interface to spacepaste-based pastebins
" Maintainer:    Jeremy Cantrell <jmcantrell@gmail.com>
" Last Modified: Sun 2012-07-15 23:14:13 (-0400)

" Most of this was taken from the lodgeit.vim plugin

if exists('g:spacepaste_loaded') || &cp
    finish
endif

let g:spacepaste_loaded = 1

let s:save_cpo = &cpo
set cpo&vim

if !exists('g:spacepaste_url')
    let g:spacepaste_url = 'http://bpaste.net'
endif

function! s:Init()
python << EOF

import vim
import re
from xmlrpclib import ServerProxy

server_url = vim.eval('g:spacepaste_url')

srv = ServerProxy(server_url+'/xmlrpc/', allow_none=True)

new_paste = srv.pastes.newPaste
get_paste = srv.pastes.getPaste

language_mapping = {
    'cs':               'csharp',
    'htmldjango':       'html+django',
    'django':           'html+django',
    'htmljinja':        'html+django',
    'jinja':            'html+django',
    'htmlgenshi':       'html+genshi',
    'genshi':           'genshi',
    'htmlmako':         'html+mako',
    'mako':             'mako',
    'javascript':       'js',
    'php':              'html+php',
    'xhtml':            'html'
}

language_reverse_mapping = {}
for key, value in language_mapping.iteritems():
    language_reverse_mapping[value] = key

def paste_id_from_url(url):
    regex = re.compile(r'^'+server_url+'/show/([^/]+)/?$')
    m = regex.match(url)
    if m is not None:
        return m.group(1)

def make_utf8(code):
    enc = vim.eval('&fenc') or vim.eval('&enc')
    return code.decode(enc, 'ignore').encode('utf-8')

EOF
endfunction

function! s:Spacepaste(line1,line2,count,...)
call s:Init()
python << endpython

# download paste
if vim.eval('a:0') == '1':
    paste = paste_id = None
    arg = vim.eval('a:1')

    if arg.startswith('#'):
        paste_id = arg[1:].split()[0]
    if paste_id is None:
        paste_id = paste_id_from_url(vim.eval('a:1'))
    if paste_id is not None:
        paste = get_paste(paste_id)

    if paste:
        vim.command('tabnew')
        vim.command('file Paste\ \#%s' % paste_id)
        vim.current.buffer[:] = paste['code'].splitlines()
        vim.command('setlocal ft=' + language_reverse_mapping.
                    get(paste['language'], 'text'))
        vim.command('setlocal nomodified')
        vim.command('let b:spacepaste_paste_id="%s"' % paste_id)
    else:
        print 'Paste not Found'

# new paste or reply
else:
    rng_start = int(vim.eval('a:line1')) - 1
    rng_end = int(vim.eval('a:line2'))
    if int(vim.eval('a:count')):
        code = '\n'.join(vim.current.buffer[rng_start:rng_end])
    else:
        code = '\n'.join(vim.current.buffer)
    code = make_utf8(code)

    parent = None
    update_buffer_info = False
    if vim.eval('exists("b:spacepaste_paste_id")') == '1':
        parent = int(vim.eval('b:spacepaste_paste_id'))
        update_buffer_info = True

    if vim.eval('exists("b:spacepaste_language")') == '1':
        language = vim.eval('b:spacepaste_language')
    else:
        ft = vim.eval('&ft').split('.')[0] or 'text'
        language = language_mapping.get(ft, ft)

    paste_id = new_paste(language, code, parent)
    url = server_url+'/show/%s' % paste_id

    print 'Pasted #%s to %s' % (paste_id, url)
    vim.command(':call setreg(\'+\', %r)' % url)

    if update_buffer_info:
        vim.command('file Paste\ \#%s' % paste_id)
        vim.command('setlocal nomodified')
        vim.command('let b:spacepaste_paste_id="%s"' % paste_id)

endpython
endfunction

command! -range=0 -nargs=* Spacepaste :call s:Spacepaste(<line1>,<line2>,<count>,<f-args>)

let &cpo = s:save_cpo
