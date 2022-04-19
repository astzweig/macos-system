#!/usr/bin/env zsh
# vi: ft=zsh

function ensureRightAccess() {
  local filesystemItem="$1"
  chown root:admin "${filesystemItem}"
  chmod ugo=rx "${filesystemItem}"
}

function configure_system() {
  local dstDir='/usr/local/bin'
  ensurePathOrLogError ${dstDir} 'Could not install binaries.' || return 10
  pushd -q ${_DIR}/../bin
  for file in *; do
    indicateActivity cp,${file},${dstDir} "Copying ${file}"
    ensureRightAccess "${dstDir}/${file}"
  done
  popd -q
}

function getExecPrerequisites() {
  cmds=(
    [cp]=''
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
