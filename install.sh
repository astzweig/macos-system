#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

runModule() {
	"$@"
}

function askNecessaryQuestions() {
	local mod= configArgs=()
	config setappname "de.astzweig.macos.system-setup"
	if [ -n "${config_only}" ]; then
		lop -- -d "Config only option given with value:" -d "${config_only}"
		config setconfigfile "${config_only}"
	elif [ -n "${config}" ]; then
		config setconfigfile "${config}"
		configArgs=(-x)
	fi
	askUserModuleQuestions ${configArgs} -c config -v moduleAnswers ${modulesToInstall}
}

function printModulesToInstall() {
	lop -- -d 'Modules that will install are:' -d "${modulesToInstall}"
	for mod in "${modulesToInstall[@]}"; do
		print "${mod}"
	done | abbreviatePaths
	exit 0
}

function generateModuleOptions() {
	local value answerKey optionKey argName
	for answerKey in ${(k)moduleAnswers}; do
		[[ ${answerKey} = ${mod}_* ]] || continue
		optionKey="${answerKey#${mod}_}"
		argName=${optionKey//_/-};
		value="${moduleAnswers[${answerKey}]}"
		if [[ "${optionKey}" =~ ^[[:alpha:]]$ ]]; then
			moduleOptions+=("-${argName}" "${value}")
		elif [[ "${optionKey}" =~ ^[[:alpha:]][-[:alpha:]]+$ ]]; then
			moduleOptions+=("--${argName}" "${value}")
		else
			moduleOptions+=("${argName}" "${value}")
		fi
	done
}

function filterPasswordOptions() {
	local opt= hide=false
	for opt in ${moduleOptions}; do
		[[ ${hide} = true ]] && { opt='******'; hide=false }
		[[ $opt =~ ^--?.*password ]] && hide=true
		filteredOptions+=($opt)
	done
}

function installModules() {
	local mod moduleOptions filteredOptions
	for mod in ${modulesToInstall}; do
		moduleOptions=()
		filteredOptions=()
		generateModuleOptions
		filterPasswordOptions
		[[ "${verbose}" == true ]] && moduleOptions+=(-v)
		[[ -n ${logfile} ]] && moduleOptions+=(-d ${logfile})
		lop -- -d "Running ${mod}" -d "with ${#moduleOptions} args:" -d "${filteredOptions}"
		runModule ${mod} ${moduleOptions}
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
	isMacOS || { lop -- -e 'This setup is only for macOS 10.13 and up.'; return 10 }
	isPlistBuddyInstalled || { lop -- -e 'This setup requires PlistBuddy to be either at /usr/libexec or in any of the PATH directories.'; return 11 }
}

function configureTerminal() {
	if [ -t 0 ]; then
		traps+=("stty $(stty -g)")
		stty -echo
	fi
	if [ -t 1 ]; then
		traps+=('tput cnorm')
		tput civis
		export TERMINAL_CURSOR_HIDDEN=true
	fi
}

function main() {
	local traps=()
	configureTerminal
	trap ${(j.;.)traps} INT TERM EXIT
	autoloadZShLib || return
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
	  --host-specific          Include host-specific default modules.
	  --host-specific-only     Include only host-specific default modules.
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
	local -A moduleAnswers
	configureLogging
	lop -- -d "Current working dir is: `pwd`"
	lop -- -d "Called main with $# args: $*"

	[[ -n ${noninteractive} && -z ${config} ]] && { lop -- -e 'A config file must be provided in noninteractive mode.'; return 10 }

	[[ ${host_specific_only} == 'false' ]] && modpath+=("${_DIR}/modules")
	[[ ${host_specific} == 'true' || ${host_specific_only} == 'true' ]] && modpath+=("${_DIR}/modules/host-specific")
	loadModules -v modulesToInstall ${$(echo -m):^^modpath} "${module[@]}"
	[ "${list}" = true ] && printModulesToInstall

	askNecessaryQuestions
	[ -z "${config_only}" ] || return 0
	requireRootPrivileges
	installModules
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
	_DIR="${0:A:h}"
	export ASTZWEIG_MACOS_SYSTEM_LIB=${_DIR}/modules/lib.sh
	export ASTZWEIG_ZSHLIB=${_DIR}/zshlib
	source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
	main "$@"
fi
