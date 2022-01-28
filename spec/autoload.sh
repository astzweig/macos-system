#!/usr/bin/env zsh
FPATH="`pwd`/zshlib:${FPATH}"
local funcNames=("${(@f)$(find . -type f -perm +u=x -maxdepth 1 | awk -F/ '{ print $NF }')}")
autoload -Uz "${funcNames[@]}"
