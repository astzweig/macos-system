#!/usr/bin/env zsh

function autoloadZShLib() {
  test -d "${ASTZWEIG_ZSHLIB}" || { echo "This module needs astzweig/zshlib to work." >&2; return 99 }
  FPATH="${ASTZWEIG_ZSHLIB}:${FPATH}"
  local funcNames=(${(f)"$(find "${ASTZWEIG_ZSHLIB}" -type f -perm +u=x -maxdepth 1 | awk -F/ '{ print $NF }')"})
  autoload -Uz "${funcNames[@]}"
}

function isDebug() {
  test "${MACOS_SYSTEM_DEBUG}" = true -o "${MACOS_SYSTEM_DEBUG}" = 1
}

function configureLogging() {
  local output=tostdout level=info
  [ -n "${logfile}" ] && output=${logfile}
  [ "${verbose}" = true ] && level=debug
  lop setoutput -l ${level} ${output}
}

function getModuleAnswerByKeyRegEx() {
  local key value
  local searchRegEx=$1
  for key moduleAnswer in ${modkey:^modans}; do
    [[ $key =~ $searchRegEx ]] && return 0
  done
  return 1
}

function checkCommands() {
  local cmd
  for cmd in ${(k)cmds}; do
    if ! which "${cmd}" >&! /dev/null; then
      local comment=''
      [ -n "${cmds[$cmd]}" ] && comment=" ${cmds[$cmd]}"
      lop -- -e "This module needs ${cmd}${comment} to work."
      return 11
    fi
  done
}

function checkHelpPrerequisites() {
  local -A cmds
  getHelpPrerequisites || return
  checkCommands
}

function addDocoptsToCmds() {
  cmds+=(docopts '(with -f option supported)')
}

function requireRootPrivileges() {
  test "`id -u`" -eq 0 || { lop -- -e 'This module requires root access. Please run as root.'; return 11 }
}

whence getHelpPrerequisites >&! /dev/null || function $_() {
  addDocoptsToCmds
}

function checkQuestionsPrerequisites() {
  local -A cmds
  getQuestionsPrerequisites || return
  checkCommands
}

function checkExecPrerequisites() {
  local -A cmds
  getExecPrerequisites || return
  checkCommands
}

function showQuestions() {
  local questions=()
  getQuestions
  for question in ${questions}; do
    hio -- body "${question}"
  done
}

function module_main() {
  local cmdName=${1:t}
  shift
  autoloadZShLib || return
  checkHelpPrerequisites || return
  configureLogging
  eval "`getUsage $cmdName | docopts -f -V - -h - : "$@"`"
  checkQuestionsPrerequisites || return
  [ "${show_questions}" = true ] && { showQuestions; return }
  checkExecPrerequisites || return
  configure_system
}

function {
  local name
  for name in getQuestionsPrerequisites getExecPrerequisites getQuestions getUsage; do
    whence ${name} >&! /dev/null || function $_() {}
  done
}
