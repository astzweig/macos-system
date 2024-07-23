#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function brewInstall() {
	local identifier="$1"
	local cask="${2:+--cask}"
	indicateActivity -- "Installing ${identifier}${cask:+ (Cask)}" ${homebrew_path} install -q ${cask} ${identifier}
}

function installCask() {
	brewInstall $1 cask
}

function installBrew() {
	brewInstall $1
}

function installCasks() {
	lop -y body:h1 -- -i 'Installing Homebrew casks'
	if ! isDebug; then
		installCask sketch
		installCask nova
		installCask transmit
		installCask automattic-texts
		installCask synology-drive
		installCask sf-symbols
		installCask prizmo
		installCask rectangle
		installCask launchcontrol
		installCask 1password
	fi
}

function installFonts() {
}

function installBrews() {
	lop -y body:h1 -- -i 'Installing Homebrew formulas'
	installBrew mas
	if ! isDebug; then
		installBrew python
		installBrew rcm
		installBrew php
		installBrew composer
		installBrew curl
		installBrew exiftool
		installBrew ffmpeg
		installBrew gnupg
		installBrew node
		installBrew nmap
		installBrew tree
		installBrew yubico-piv-tool
	fi
}

function configure_system() {
	lop -y h1 -- -i 'Install Homebrew Applications'
	pushd -q /
	installBrews
	installCasks
	installFonts
	popd -q
}

function getExecPrerequisites() {
	cmds=(
		[brew]=''
		[find]=''
		[head]=''
		[installer]=''
		[hdiutil]=''
	)
	id -nG | grep admin >&! /dev/null || { lop -- -e 'This module requires the user to be in admin group. Please run again as either root or an admin user.'; return 11 }
	checkCommands
}

function getDefaultHomebrewPath() {
	local moduleAnswer
	local hbpath=`whence -p brew`
	getModuleAnswerByKeyRegEx '_homebrew-prefix$' && hbpath=$moduleAnswer/bin/brew
	print -- ${hbpath}
}

function getQuestions() {
	questions=(
		'i: homebrew-path=Which Homebrew binary shall be used? # default:'"$(getDefaultHomebrewPath)"
	)
}

function getUsage() {
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --homebrew-path PATH

	Install cli tools, macOS apps and fonts via Homebrew.

	Options:
	  --homebrew-path PATH     Path to Homebrew binary [default: $(getDefaultHomebrewPath)].
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
