#!/usr/bin/env zsh
# vi: ft=zsh

function installMASApp() {
  local currentUser="`who am i | cut -d' ' -f1`"
  local appName="$1"
  local id="$2"
  indicateActivity -- "Install ${appName} app" sudo -u ${currentUser} mas install ${id}
}

function configure_system() {
  lop -y h1 -- -i 'Install Mac AppStore Apps'
  installMASApp Keka 470158793

  if ! isDebug; then
    installMASApp Pages 409201541
    installMASApp Numbers 409203825

    installMASApp Outbank 1094255754
    installMASApp Telegram 747648890
    installMASApp 1Password 1333542190

    installMASApp 'Final Cut Pro' 424389933
    installMASApp GarageBand 682658836
    installMASApp Motion 434290957
    installMASApp Compressor 424390742
    installMASApp 'Logic Pro' 634148309
  fi
}

function getExecPrerequisites() {
  cmds=(
    [mas]=''
    [sudo]=''
    [who]=''
    [cut]=''
  )
}

function getQuestions {
  questions=(
    'c: logged-in=Have you ensured a user is logged in to the macOS App Store?'
  )
}

function getUsage() {
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --logged-in ANS
	
	Install macOS applications from Apple's macOS App Store.
	
	Options:
	  -l ANS, --logged-in ANS  This option is to ensure, that the caller has
	                           checked that a user is logged in to the App Store.
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
