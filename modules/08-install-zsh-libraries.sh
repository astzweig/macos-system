#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function installZshlib() {
	/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/astzweig/zshlib/main/bootstrap.sh)"
  [[ -f '/usr/local/share/zsh/site-functions/zshlib.zwc' ]]
}

function installMacOSSystemLibrary() {
  ensureLocalBinFolder
  local destPath=/usr/local/bin/macos-system-lib.sh
  cp ${ASTZWEIG_MACOS_SYSTEM_LIB} $destPath
  chown root:admin $destPath
  chmod ugo=r $destPath
}

function configure_system() {
	lop -y h1 -- -i 'Install ZSh Library'
	indicateActivity -- 'Install zshlib' installZshlib
	indicateActivity -- 'Install macos-system library' installMacOSSystemLibrary
}

function getExecPrerequisites() {
	cmds=(
		[zsh]=''
		[curl]=''
	)
}

function getUsage() {
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE]

	Install convenient zsh libraries system-wide for use in zsh scripts.

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
