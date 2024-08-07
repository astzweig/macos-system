#!/usr/bin/env zsh
# vi: ft=zsh

function getExecPrerequisites() {
	cmds=(
    [azw]=''
		[azw-set-hostname]=''
	)
}

function getQuestions() {
	questions=(
		'i: hostname=What shall the hostname of this host be?'
	)
}

function configure_system() {
	lop -y h1 -- -i 'Configure System Hostname'
	azw set-hostname --hostname ${hostname}
}

function getUsage() {
	local cmdName=$1 text=''
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --hostname NAME

	Configure hostname.

	Options:
	  --hostname NAME          Set NAME as current host's host name.
	  -d FILE, --logfile FILE  Print log message to logfile instead of stdout.
	  -v, --verbose            Be more verbose.
	----
	$cmdName 0.1.0
	Copyright (C) 2022 Rezart Qelibari, Astzweig GmbH & Co. KG
	License EUPL-1.2. There is NO WARRANTY, to the extent permitted by law.
	USAGE
	print -- ${text}
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
	test -f "${ASTZWEIG_MACOS_SYSTEM_LIB}" || { echo 'This module requires macos-system library. Please run again with macos-system library provieded as a path in ASTZWEIG_MACOS_SYSTEM_LIB env variable.'; return 10 }
	source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
	module_main $0 "$@"
fi
