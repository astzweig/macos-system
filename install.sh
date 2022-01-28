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
  local funcNames=("${(@f)$(find ./zshlib -type f -perm +u=x -maxdepth 1 | awk -F/ '{ print $NF }')}")
  autoload -Uz "${funcNames[@]}"
}

function getFilteredModules() {
  if [ "${#module}" -eq 0 ]; then
    echo "${allModules[@]}"
  else
    local modulesToKeep=()
    for mod in "${allModules[@]}"; do
      local foundAtIndex="${module[(Ie)${mod}]}"
      if [ "${inverse}" != 'true' -a "${foundAtIndex}" -gt 0 ]; then
        modulesToKeep+=("${mod}")
      elif [ "${inverse}" = 'true' -a "${foundAtIndex}" -eq 0 ]; then
        modulesToKeep+=("${mod}")
      fi
    done
    echo "${modulesToKeep[@]}"
  fi
}

function main() {
  eval "`docopts -f -V - -h - : "$@" <<- USAGE
  Usage: $0 [options] [<module>...]

  Install all included modules. If any <module> arg is given, install only those
  modules.

  Options:
    -i, --inverse  Exclude the given <module> instead.
  ----
	$0 0.1.0
	Copyright (C) 2022 Rezart Qelibari, Astzweig GmbH & Co. KG
	License EUPL-1.2. There is NO WARRANTY, to the extent permitted by law.
  USAGE`"
  local allModules=()
  local modulesToInstall=(`getFilteredModules`)
  ensureDocopts
  autoloadZShLib
  hio debug "Current working dir is: `pwd`"
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  main
fi
