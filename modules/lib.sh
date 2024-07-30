#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function autoloadZShLib() {
	[[ -d ${ASTZWEIG_ZSHLIB} || -f ${ASTZWEIG_ZSHLIB} ]] || { echo "This module needs astzweig/zshlib to work." >&2; return 99 }
	fpath+=(${ASTZWEIG_ZSHLIB})
	if [[ -d ${ASTZWEIG_ZSHLIB} ]]; then
		local funcNames=($(find "${ASTZWEIG_ZSHLIB}" -type f -perm +u=x -maxdepth 1 | awk -F/ '{ print $NF }'))
		autoload -Uz ${funcNames}
	elif [[ -f ${ASTZWEIG_ZSHLIB} ]]; then
		autoload -Uzw ${ASTZWEIG_ZSHLIB}
	fi
}

function isDebug() {
	test "${MACOS_SYSTEM_DEBUG}" = true -o "${MACOS_SYSTEM_DEBUG}" = 1
}

function ensureLocalBinFolder() {
  local folder="/usr/local/bin"
  if [[ ! -d "${folder}" ]]; then
    mkdir -p "${folder}" 2> /dev/null || {
      lop -- -e 'Could not create directory' -e $folder
      return 10
    }
    chown root:admin "${folder}"
    chmod ug=rwx,o=rx "${folder}"
  fi
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

function ensurePathOrLogError() {
	local dir=$1 msg=$2
	[[ -d ${dir} ]] || install -m $(umask -S) -d $(getMissingPaths ${dir}) || {
		lop -- -e "$msg" -e "Directory ${dir} does not exist and could not be created."
		return 10
	}
}

function checkHelpPrerequisites() {
	local -A cmds
	getHelpPrerequisites || return
	checkCommands ${(k)cmds}
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
	checkCommands ${(k)cmds}
}

function checkExecPrerequisites() {
	local -A cmds
	getExecPrerequisites || return
	checkCommands ${(k)cmds}
}

function showQuestions() {
	local questions=()
	getQuestions
	for question in ${questions}; do
		hio -- body "${question}"
	done
}

function module_main() {
	local cmdPath=${1} cmdName=${1:t} hookBag=()
	local -A traps=()
	preCommandNameHook "$@" || return
	shift
	autoloadZShLib || return
	preHelpHook "$@" || return
	checkHelpPrerequisites || return
	configureLogging
	trap 'traps call int; return 70' INT
	trap 'traps call term; return 80' TERM
	trap 'traps call exit' EXIT
	eval "`getUsage $cmdName | docopts -f -V - -h - : "$@"`"
	preQuestionHook "$@" || return
	checkQuestionsPrerequisites || return
	[ "${show_questions}" = true ] && { showQuestions; return }
	preExecHook "$@" || return
	checkExecPrerequisites || return
	configure_system
}

function {
	local name
	for name in preCommandNameHook preHelpHook preQuestionHook preExecHook getQuestionsPrerequisites getExecPrerequisites getQuestions getUsage; do
		whence ${name} >&! /dev/null || function $_() {}
	done
}
