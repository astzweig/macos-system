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
		[osascript]=''
		[scutil]=''
		[systemsetup]=''
	)
}

function getQuestions() {
	local timezones
	timezones="`systemsetup -listtimezones | tail -n +2 | awk '{print $1}' | paste -sd, -`"
	questions=(
		'i: hostname=What shall the hostname of this host be?'
		's: timezone=What shall the timezone of this host be? # choose from:'"${timezones};"
	)
}

function quitSystemPreferences() {
	ps -A -o pid,comm | grep "MacOS/System Settings" | awk '{print "kill -9 " $1}' | /bin/sh
}

function setComputerName() {
	scutil --set ComputerName "${hostname}"
	scutil --set HostName "${hostname}"
	scutil --set LocalHostName "${hostname}"
	systemsetup -setcomputername "${hostname}"
	systemsetup -setlocalsubnetname "${hostname}"
}

function configureComputerHostname() {
	local currentComputerName="`scutil --get ComputerName`"
	if [[ "${currentComputerName}" != "${hostname}" ]]; then
		lop -- -i 'Hostname of computer has not been set.' -i "Will set to ${hostname}."
		indicateActivity -- 'Set computer name' setComputerName
	else
		lop -- -i 'Hostname of computer seems to have already been set. Skipping.' -i "Hostname: $currentComputerName"
	fi
}

function configureTimezone(){
	systemsetup -settimezone "${timezone}" >&! /dev/null
}

function configure_system() {
	lop -y h1 -- -i 'Configure System Settings'
	indicateActivity -- 'Quitting System Preferences' quitSystemPreferences
	configureComputerHostname
	indicateActivity -- 'Configuring timezone' configureTimezone
}

function getUsage() {
	local cmdName=$1 text=''
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --hostname NAME --timezone ZONE

	Configure host specific settings.

	Options:
	  --hostname NAME          Set NAME as current host's host name.
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
