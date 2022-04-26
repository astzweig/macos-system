#!/usr/bin/env zsh
# vi: ft=zsh

function ensureRightAccess() {
  local filesystemItem="$1"
  chown root:admin "${filesystemItem}"
  chmod ugo=rx "${filesystemItem}"
}

function copyUtilityBinaries() {
  for file in ${_DIR}/../bin/*; do
    indicateActivity cp,${file},${dstDir} "Copying ${file##*/}"
    ensureRightAccess ${file}
  done
}

function installDocopts() {
  local destPath='/usr/local/bin/docopts'
  [[ -x ${destPath} ]] && return
  indicateActivity curl,--output,${destPath},-fsSL,"${docopts_url}" 'Downloading docpts' || return
  chown root:admin ${destPath}
  chmod 755 ${destPath}
}

function configure_system() {
  lop -y h1 -- -i 'Install Utility Binaries'
  local dstDir='/usr/local/bin'
  ensurePathOrLogError ${dstDir} 'Could not install binaries.' || return 10
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

function getDefaultDocoptsURL() {
  local fileURL="${DOCOPTS_URL:-https://github.com/astzweig/docopts/releases/download/v.0.7.0/docopts_darwin_amd64}"
  print -- ${fileURL}
}

function getQuestions() {
  questions=(
    'i: docopts-url=From which URL shall the docopts binary be downloaded? # default:'"$(getDefaultDocoptsURL)"
  )
}

function getUsage() {
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --docopts-url URL
	
	Install convenient binaries for all users.
	
	Options:
	  --docopts-url URL        The URL from which to download the docopts binary
	                           [default: $(getDefaultDocoptsURL)].
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
