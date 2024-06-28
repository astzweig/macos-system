#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function installGoogleFonts() {
  local fontsDir=/Library/Fonts/Google-Fonts
  [[ -d ${fontsDir} ]] && return
  indicateActivity 'Download Google Fonts' git clone "${git_google_fonts}" "${fontsDir}"
  indicateActivity 'Fix Directory Permissions' find ${fontsDir} -type d -mindepth 1 -exec chmod g+rwx,o+rx {} \;
  indicateActivity 'Fix File Permissions' find ${fontsDir} -type f -mindepth 1 -exec chmod g+rw,o+r {} \;
}

function configure_system() {
  lop -y h1 -- -i 'Install Fonts'
}

function getExecPrerequisites() {
  cmds=(
    [git]=''
  )
}

function getDefaultGitGoogleFontsURL() {
  print -- ${GOOGLE_FONTS_GIT_REMOTE:-https://github.com/google/fonts.git}
}

function getQuestions() {
  questions=(
    'i: git-google-fonts=Which Git repository shall be used to install Google Fonts from? # default:'"$(getDefaultGitGoogleFontsURL)"
  )
}

function getUsage() {
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --git-google-fonts URL
	
	Install different fonts system wide (for all users).
	
	Options:
	  --git-google-fonts URL   Git URL to the Google Fonts repository [default: $(getDefaultGitGoogleFontsURL)].
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
