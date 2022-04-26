#!/usr/bin/env zsh
# vi: ft=zsh

function addLibToStartupFile() {
}

function installZshlib() {
  local zshlibPath=${libDir}/astzweig_zshlib
  pushd -q ${ASTZWEIG_ZSHLIB}
  zcompile -z -U ${zshlibPath} $(find . -type f -perm +u=x -maxdepth 1)
  libs+=(${zshlibPath}.zwc)
  popd -q
}

function modifyGlobalFpath() {
  local startupFile=/etc/zshenv
  cat ${startupFile} | grep "${(q)libs}" >&! /dev/null && return
  print -- "fpath+=(${(q)libs})" >> ${startupFile}
  chown root:wheel ${startupFile}
  chmod u=rw,go=r ${startupFile}
}

function configure_system() {
  lop -y h1 -- -i 'Install ZSh Libraries'
  local libDir=/usr/local/share/zsh/site-functions
  local libs=()
  ensurePathOrLogError ${libDir} 'Could not install zsh libraries.' || return 10
  lop -- -d "ASTZWEIG_ZSHLIB is ${ASTZWEIG_ZSHLIB}"
  indicateActivity installZshlib 'Install zshlib'
  indicateActivity modifyGlobalFpath 'Modify global fpath'
}

function getExecPrerequisites() {
  cmds=(
    [cat]=''
    [grep]=''
    [chown]=''
    [chmod]=''
    [install]=''
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
