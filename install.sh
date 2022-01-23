#!/usr/bin/env zsh
# vi: set expandtab ft=zsh tw=80 ts=2

function ensureDocopts() {
  which docopts > /dev/null
  [ $? -eq 0 ] && return
  curl --output ./docopts -fsSL https://github.com/astzweig/docopts/releases/download/v.0.7.0/docopts_darwin_amd64
  chmod u+x ./docopts
  PATH="`pwd`:${PATH}"
}

function autoloadZShLib() {
  FPATH="`pwd`/zshlib:${FPATH}"
  local funcNames=("${(@f)$(find ./zshlib -type f -perm +u=x | awk -F/ '{ print $NF }')}")
  autoload -Uz "${funcNames[@]}"
}

function main() {
  ensureDocopts
  autoloadZShLib
  hio debug "Current working dir is: `pwd`"
}

main
