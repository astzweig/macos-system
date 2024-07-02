#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function ensureRightAccess() {
	local filesystemItem="$1"
	chown root:admin "${filesystemItem}"
	chmod ugo=rx "${filesystemItem}"
}

function copyUtilityBinaries() {
	for file in ${_DIR}/../bin/*; do
		indicateActivity -- "Copying ${file##*/}" cp ${file} ${dstDir}
		ensureRightAccess ${file}
	done
}

function installDocopts() {
	local destPath='/usr/local/bin/docopts'
	[[ -x ${destPath} ]] && return
	local docoptsURL="https://github.com/astzweig/docopts/releases/download/v.0.7.0/docopts_darwin_amd64"
	[[ $(uname -m) == arm64 ]] && docoptsURL="https://github.com/astzweig/docopts/releases/download/v.0.7.0/docopts_darwin_arm64"
	indicateActivity -- 'Downloading docpts' curl --output ${destPath} -fsSL ${docoptsURL} || return
	ensureRightAccess ${destPath}
}

function configure_system() {
	lop -y h1 -- -i 'Install Utility Binaries'
	local dstDir='/usr/local/bin'
	ensurePathOrLogError ${dstDir} 'Could not install binaries.' || return 10
	indicateActivity -- "Set sticky bit to ${dstDir} folder" chmod +t ${dstDir}
	installDocopts
	copyUtilityBinaries
}

function getExecPrerequisites() {
	cmds=(
		[cp]=''
		[chown]=''
		[chmod]=''
		[curl]=''
		[install]=''
	)
}

function getUsage() {
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE]

	Install convenient binaries for all users.

	Options:
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
	_DIR="${0:A:h}"
	test -f "${ASTZWEIG_MACOS_SYSTEM_LIB}" || { echo 'This module requires macos-system library. Please run again with macos-system library provieded as a path in ASTZWEIG_MACOS_SYSTEM_LIB env variable.'; return 10 }
	source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
	module_main $0 "$@"
fi
