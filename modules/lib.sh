#!/usr/bin/env zsh

function autoloadZShLib() {
  test -d "${ASTZWEIG_ZSHLIB}" || { echo "This module needs astzweig/zshlib to work." >&2; return 99 }
  FPATH="${ASTZWEIG_ZSHLIB}:${FPATH}"
  local funcNames=(${(f)"$(find "${ASTZWEIG_ZSHLIB}" -type f -perm +u=x -maxdepth 1 | awk -F/ '{ print $NF }')"})
  autoload -Uz "${funcNames[@]}"
}

function configureLogging() {
  local output=tostdout level=info
  [ -n "${logfile}" ] && output=${logfile}
  [ "${verbose}" = true ] && level=debug
  lop setoutput -l ${level} ${output}
}

function checkCommands() {
  local cmd
  for cmd in ${(k)cmds}; do
    if ! which "${cmd}" >&! /dev/null; then
      local comment=''
      [ -n "${cmds[$cmd]}" ] && comment=" ${cmds[$cmd]}"
      lop error "This module needs ${cmd}${comment} to work."
      return 11
    fi
  done
}

function showQuestions() {
  local questions=()
  getQuestions
  for question in ${questions}; do
    hio info "${question}"
  done
}

function module_main() {
  local cmdName=${1:t}
  shift
  autoloadZShLib || return
  checkPrerequisites || return
  eval "`getUsage $cmdName | docopts -f -V - -h - : "$@"`"
  [ $# -lt 1 ] && return
  configureLogging
  [ "${show_questions}" = true ] && { showQuestions; return }
  configure_system
}
