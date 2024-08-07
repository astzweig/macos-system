#!/usr/bin/env zsh
# vi: ft=zsh

function getQuestionsPrerequisites() {
	cmds=(
		[systemsetup]=''
	)
	requireRootPrivileges
}

function getExecPrerequisites() {
	cmds=(
		[systemsetup]=''
	)
}

function getQuestions() {
	local timezones
	timezones="`systemsetup -listtimezones | tail -n +2 | awk '{print $1}' | paste -sd, -`"
	questions=(
		's: timezone=What shall the timezone of this host be? # choose from:'"${timezones};"
	)
}

function configureTimezone(){
	systemsetup -settimezone "${timezone}" >&! /dev/null
}

function configure_system() {
	lop -y h1 -- -i 'Configure System Timezone'
	indicateActivity -- 'Configuring timezone' configureTimezone
}

function getUsage() {
	local cmdName=$1 text=''
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --hostname NAME --timezone ZONE

	Configure system timezone.

	Options:
		--timezone ZONE          Set ZONE as current host's timezone [default: Europe/Berlin].
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
