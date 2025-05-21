#!/usr/bin/env bash
#
# In order for Unity to generate project files it needs to think vscode is the
# editor, so we can link this script in place of vscode's binary to open
# neovide at a file or log location instead.
#
IFS=':' read -r FILE LINE COL <<<"$3"
COL=$((COL + 1))

if [[ ! -S /tmp/nvimsocket ]]; then
    /opt/homebrew/bin/neovide &
    sleep 1
fi

/opt/homebrew/bin/nvim --server /tmp/nvimsocket --remote-send \
    ":e ${FILE// /\\ }<cr>:call cursor(${LINE},${COL})<cr>:NeovideFocus<cr>"
