#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function getDefaultFilevaultUsername() {
	print 'azwdevice'
}

function createLaunchDaemon() {
	cat > ${launchDaemonPath} <<- LDAEMON
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
		<dict>
			<key>Label</key>
			<string>${serviceName}</string>
			<key>ProgramArguments</key>
			<array>
					<string>/usr/local/bin/azw</string>
					<string>ensure-single-fv-user</string>
					<string>${filevault_username}</string>
			</array>
			<key>OnDemand</key>
			<false/>
			<key>LaunchOnlyOnce</key>
			<true/>
		</dict>
	</plist>
	LDAEMON
	chown root:wheel $launchDaemonPath
	chmod ugo=r $launchDaemonPath
}

function enableLaunchDaemon() {
	launchctl enable system/${launchDaemonPath%.*}
	launchctl bootstrap system ${launchDaemonPath}
}

function createLaunchdService() {
	local serviceName='de.astzweig.macos.launchdaemons.ensure-single-filevault-user'
	local launchDaemonPath="/Library/LaunchDaemons/${serviceName}.plist"
	[[ -f ${launchDaemonPath} ]] || indicateActivity -- 'Create Launch Daemon' createLaunchDaemon
	indicateActivity -- 'Enable Launch Daemon' enableLaunchDaemon
}

function configure_system() {
	lop -y h1 -- -i 'Allow only Filevault user to unlock disk'
	createLaunchdService
}

function getHelpPrerequisites() {
	cmds=()
	addDocoptsToCmds
}

function getQuestionsPrerequisites() {
	cmds=()
}

function getExecPrerequisites() {
	cmds=(
		[awk]=''
		[cat]=''
		[fdesetup]=''
	)
	requireRootPrivileges
}

function getQuestions() {
	local defaultUsername="`getDefaultFilevaultUsername`"
	questions=(
		'i: filevault-username=What shall the FileVault user'\''s username be? # default:'"${defaultUsername}"
	)
}

function getUsage() {
	local cmdName=$1 text='' varname=
	local defaultUsername="`getDefaultFilevaultUsername`"
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] [--filevault-username NAME]

	Create a script that ensures only a specified user of all FileVault enabled
	users can unlock FileVault. That way a secure password can be used to
	unlock the disk as opposed to macOS standard, where each user is allowed to
	unlock the disk with his password that may or may not be secure (in terms of
	length and randomness).

	Options:
	  --filevault-username NAME             Username of the designated FileVault user [default: ${defaultUsername}].
	  -d FILE, --logfile FILE               Print log message to logfile instead of stdout.
	  -v, --verbose                         Be more verbose.
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
