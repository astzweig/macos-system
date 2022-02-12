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

function configureLogging() {
  local output=tostdout level=info
  [ -n "${logfile}" ] && output="${logfile}"
  [ "${verbose}" = true ] && level=debug
  lop setoutput -l "${level}" "${output}"
}

function filterModules() {
  if [ "${#module}" -eq 0 ]; then
    modulesToInstall=("${allModules[@]}")
  else
    local mod pattern="^.*(${(j.|.)module})\$"
    modulesToInstall=()
    for mod in "${allModules[@]}"; do
      local found=false
      [[ "${mod}" =~ ${pattern} ]] && found=true
      if [ "${inverse}" != 'true' -a "${found}" = true ]; then
        modulesToInstall+=("${mod}")
      elif [ "${inverse}" = 'true' -a "${found}" = false ]; then
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
  for line in "${(f)$(runModule "${mod}" --show-required-information)}"; do
    parseQuestionLine
  done
}

function convertQuestionArgsToAskUserArgs() {
  local arg argName argValue
  local instructions=("${(s.;.)questionArgs}")
  local questionType="${instructions[1]}"
  shift instructions

  if [ "${questionType}" = 'info' ]; then
    args=(info)
  elif [ "${questionType}" = 'password' ]; then
    args=('-p' info)
  elif [ "${questionType}" = 'confirm' ]; then
    args=(confirm)
  elif [ "${questionType}" = 'select' ]; then
    for arg in "${instructions[@]}"; do
      arg=("${(s.:.)arg}")
      [ "${#arg}" -lt 2 ] && continue
      argName="${arg[1]}"
      argValue="${arg[2]}"
      [ "${argName}" != 'choose from' ] && continue
      choices=("${(s.,.)argValue}")
    done
    [ "${#choices}" -ge 1 ] || return 10
    args=(choose)
  fi
}

function askUserQuestion() {
  local choices
  local questionAndArgs=("${(f)questions[$questionID]}") args=()
  local question="${questionAndArgs[1]}" questionArgs="${questionAndArgs[2]}"
  convertQuestionArgsToAskUserArgs
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
    generateConfigKeysFromQuestionID "${mod}" "${questionID}"
    value="`config read "${configkeys[@]}"`"
    if [ -z "${value}" ]; then
      askUserQuestion
      config write "${value}" "${configkeys[@]}"
    fi
    answers+=("${mod}_${questionID}" "${value}")
  done
}

function askNecessaryQuestions() {
  local mod
  config setappname "de.astzweig.macos.system-setup"
  [ -n "${config_only}" ] && config setconfigfile "${config_only}"
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
  modpath=("${_DIR}/modules" "${modpath[@]}")
  allModules=("${(f)$(find "${modpath[@]}" -type f -perm +u=x -maxdepth 1 2> /dev/null | sort -n)}")
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

function main() {
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
  ensureDocopts
  autoloadZShLib
  configureLogging
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
