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
  export ASTZWEIG_ZSHLIB="`pwd`/zshlib"
  FPATH="${ASTZWEIG_ZSHLIB}:${FPATH}"
  local funcNames=("${(@f)$(find "${ASTZWEIG_ZSHLIB}" -type f -perm +u=x -maxdepth 1 | awk -F/ '{ print $NF }')}")
  autoload -Uz "${funcNames[@]}"
}

function configureLogging() {
  local output=tostdout level=info
  [ -n "${logfile}" ] && output="${logfile}"
  [ "${verbose}" = true ] && level=debug
  lop setoutput -l "${level}" "${output}"
}

function filterModules() {
  if [ "${#module}" -eq 0 ]; then
    lop debug 'No modules given as arguments. Taking all modules.'
    modulesToInstall=("${allModules[@]}")
  else
    lop debug "Given ${#module} modules as arguments: ${module}"
    [ "${inverse}" = true ] && lop debug 'Taking complement set.'
    local mod pattern="^.*(${(j.|.)module})\$"
    modulesToInstall=()
    for mod in "${allModules[@]}"; do
      local found=false
      [[ "${mod}" =~ ${pattern} ]] && found=true
      lop debug "Was ${mod} found in ${pattern}: ${found}"
      if [ "${inverse}" != 'true' -a "${found}" = true ]; then
        lop debug "Adding module ${mod}"
        modulesToInstall+=("${mod}")
      elif [ "${inverse}" = 'true' -a "${found}" = false ]; then
        lop debug "Adding module ${mod}"
        modulesToInstall+=("${mod}")
      fi
    done
  fi
}

function runModule() {
  local mod="$1"
  shift
  "${mod}" "$@"
}

function parseQuestionLine() {
  local questionType parameterName question value arguments args
  local -A typeMap=([i]=info [p]=password [c]=confirm [s]=select)
  [ -z "${line}" ] && return
  [ "${line[2]}" != ':' ] && return 10

  questionType="${typeMap[${line[1]}]}"
  [ -z "${questionType}" ] && return 11

  # remove question type
  [ "${line[3]}" = ' ' ] && line="${line:3}" || line="${line:2}"

  line=("${(s.=.)line[@]}")
  parameterName="${line[1]}"
  [ -z "${parameterName}" ] && return 12
  [ "${parameterName[1]}" = '-' ] && return 13

  # remove parameter name
  line="${(j.=.)${(@)line:1}}"

  line=("${(s. #.)line}")
  question="${line[1]}"
  [ -z "${question}" ] && return 14

  # remove question part
  line="${(j. #.)${(@)line:1}}"

  if [ -n "${line}" ]; then
    arguments=("${(s.;.)line}")
    for arg in "${arguments[@]}"; do
      arg=("${(s.:.)arg}")
      [ -z "${arg[1]}" ] && return 15
      arg[1]="`trim "${arg[1]}"`"
      arg[2]="`trim "${arg[2]}"`"
      questionType+=";${(j.:.)arg}"
    done
  fi


  printf -v value '%s\n%s' "${question}" "${questionType}"
  questions+=("${parameterName}" "${value}")
}

function populateQuestionsWithModuleRequiredInformation() {
  lop debug "Asking ${mod} for required information"
  for line in "${(f)$(runModule "${mod}" show-questions)}"; do
    lop debug "Says line: ${line}"
    parseQuestionLine
    lop debug "Parsing question returned status: $?"
  done
  lop debug "Parsed questions are: ${(kv)questions}"
}

function findQuestionArgInInstruction() {
  local argNameToLookup="$1" arg name value
  [ -z "${argNameToLookup}" ] && return
  for arg in ${instructions[@]}; do
    arg=("${(s.:.)arg}")
    [ "${#arg}" -lt 2 ] && continue
    name="${arg[1]}"
    value="${arg[2]}"
    [ "${name}" != "${argNameToLookup}" ] && continue
    argValue="${value}"
    return
  done
  return 10
}

function convertQuestionArgsToAskUserArgs() {
  local argValue
  local instructions=("${(s.;.)questionArgs}")
  local questionType="${instructions[1]}"
  shift instructions

  if [ "${questionType}" = 'info' ]; then
    args=(info)
    if findQuestionArgInInstruction 'default'; then
      test -n "${argValue}" && args=('-d' "${argValue}" ${args})
    fi
  elif [ "${questionType}" = 'password' ]; then
    args=('-p' info)
  elif [ "${questionType}" = 'confirm' ]; then
    args=(confirm)
  elif [ "${questionType}" = 'select' ]; then
    findQuestionArgInInstruction 'choose from' || return 10
    choices=("${(s.,.)argValue}")
    [ "${#choices}" -ge 1 ] || return 11
    args=(choose)
  fi
  return 0
}

function askUserQuestion() {
  local choices
  local questionAndArgs=("${(f)questions[$questionID]}") args=()
  local question="${questionAndArgs[1]}" questionArgs="${questionAndArgs[2]}"
  convertQuestionArgsToAskUserArgs
  lop debug "Converted args for askUser are: ${args}"
  askUser "${args[@]}" "${question}"
  value="${REPLY}"
}

function generateConfigKeysFromQuestionID() {
  setopt localoptions extendedglob
  [ $# -lt 2 -o -z "$1" -o -z "$2" ] && return
  local modName="${1}" questID="${2}"
  modName="${${${${modName//-##/_}/#_/}/%_/}//[^A-Za-z_]/}"
  questID="${${${${questID//-##/_}/#_/}/%_/}//[^A-Za-z_]/}"
  configkeys=("${modName}" questions "${questID}")
}

function answerQuestionsFromConfigOrAskUser() {
  local questionID
  for questionID in "${(k)questions[@]}"; do
    local value configkeys=()
    lop debug "Answering question with ID: ${questionID}"
    generateConfigKeysFromQuestionID "${mod}" "${questionID}"
    lop debug "Config keys for question are: ${configkeys}"
    value="`config read "${configkeys[@]}"`"
    lop debug "Config answer for key is: ${value}"
    if [ -z "${value}" ]; then
      lop debug 'Asking user'
      askUserQuestion
      lop debug "User answer is: ${value}"
      [ -n "${config_only}" ] && config write "${value}" "${configkeys[@]}"
    fi
    lop debug "Adding answer: ${mod}_${questionID}=${value}"
    answers+=("${mod}_${questionID}" "${value}")
  done
}

function askNecessaryQuestions() {
  local mod
  config setappname "de.astzweig.macos.system-setup"
  if [ -n "${config_only}" ]; then
    lop debug "Config only option given with value: ${config_only}"
    config setconfigfile "${config_only}"
  fi
  for mod in ${modulesToInstall[@]}; do
    local -A questions=()
    populateQuestionsWithModuleRequiredInformation
    answerQuestionsFromConfigOrAskUser
  done
}

function printModulesToInstall() {
  lop section 'Modules that will install are:'
  for mod in "${modulesToInstall[@]}"; do
    hio info "${mod}"
  done | abbreviatePaths
  exit 0
}

function loadModules() {
  local mod
  modpath=("${_DIR}/modules" "${modpath[@]}")
  lop debug "Module paths are: ${modpath[@]}"
  allModules=("${(f)$(find "${modpath[@]}" -type f -perm +u=x -maxdepth 1 2> /dev/null | sort -n)}")
  for mod in "${allModules[@]}"; do
    lop debug "Found module ${mod}"
  done
  filterModules
  [ "${list}" = true ] && printModulesToInstall
}

function generateModuleOptions() {
  local value answerKey optionKey
  for answerKey in ${(k)answers}; do
    [[ ${answerKey} = ${mod}_* ]] || continue
    optionKey="${answerKey#${mod}_}"
    value="${answers[${answerKey}]}"
    if [[ "${optionKey}" =~ ^[[:alpha:]]$ ]]; then
      moduleOptions+=("-${optionKey}" "${value}")
    elif [[ "${optionKey}" =~ ^[[:alpha:]][-[:alpha:]]+$ ]]; then
      moduleOptions+=("--${optionKey}" "${value}")
    else
      moduleOptions+=("${optionKey}" "${value}")
    fi
  done
}

function installModules() {
  local mod moduleOptions
  for mod in "${modulesToInstall[@]}"; do
    generateModuleOptions
    runModule "${mod}" ${moduleOptions}
  done
}

function isMacOS() {
  autoload is-at-least
  [ "`uname -s`" = Darwin ] || return
  is-at-least "10.13" "`sw_vers -productVersion 2> /dev/null`"
}

function isPlistBuddyInstalled() {
  test -x /usr/libexec/PlistBuddy && return
  which PlistBuddy >&! /dev/null && return
}

function checkPrerequisites() {
  isMacOS || { lop error 'This setup is only for macOS 10.13 and up.'; return 10 }
  isPlistBuddyInstalled || { lop error 'This setup requires PlistBuddy to be either at /usr/libexec or in any of the PATH directories.'; return 11 }
  test "`id -u`" -eq 0 || { lop error 'This module requires root access. Please run as root.'; return 11 }
}

function main() {
  ensureDocopts
  autoloadZShLib
  checkPrerequisites || return
  eval "`docopts -f -V - -h - : "$@" <<- USAGE
	Usage: $0 [options] [-m PATH]... [<module>...]
	
	Install all modules in module search path. If any <module> arg is given,
	install only modules that either match any given <module> or whose path ends
	like any of the given <module>.
	
	Options:
	  -i, --inverse            Exclude the given <module> instead.
	  -m PATH, --modpath PATH  Include PATH in the module search path.
	  -c PATH, --config PATH   Read module answers from config file at PATH.
	  -l, --list               List modules that are going to be installed and
	                           exit without installation. Modules are printed in
	                           minimal but still distinct paths.
	  -d FILE, --logfile FILE  Print log message to logfile instead of stdout.
	  -v, --verbose            Be more verbose.
	  --config-only PATH       Ask module questions, generate config at PATH and
	                           exit. Useful for subsequent runs with c option.
	                           Any file at PATH will be overwritten.
	----
	$0 0.1.0
	Copyright (C) 2022 Rezart Qelibari, Astzweig GmbH & Co. KG
	License EUPL-1.2. There is NO WARRANTY, to the extent permitted by law.
	USAGE`"
  local allModules=() modulesToInstall=()
  local -A answers
  configureLogging
  lop debug "Called main with $# args: $@"
  loadModules
  askNecessaryQuestions
  [ -z "${config_only}" ] || return 0
  installModules
  lop debug "Current working dir is: `pwd`"
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  _DIR="${0:A:h}"
  main "$@"
fi
