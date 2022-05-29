#!/usr/bin/env zsh
# vi: ft=zsh

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

function patchParallels() {
  pushd -q "`brew --repo homebrew/cask 2> /dev/null`"
  git status --short --untracked-files=no | grep Casks/parallels.rb > /dev/null
  local hasBeenPatched=$?
  if [[ "${hasBeenPatched}" -ne 0 ]]; then
    echo 'diff --git a/Casks/parallels.rb b/Casks/parallels.rb
--- a/Casks/parallels.rb
+++ b/Casks/parallels.rb
@@ -31,12 +31,6 @@ cask "parallels" do
                    args: ["-d", "com.apple.FinderInfo", "#{staged_path}/Parallels Desktop.app"]
   end

-  postflight do
-    system_command "#{appdir}/Parallels Desktop.app/Contents/MacOS/inittool",
-                   args: ["init"],
-                   sudo: true
-  end
-
   uninstall_preflight do
     set_ownership "#{appdir}/Parallels Desktop.app"
   end
' | git apply || { lop -- -e 'Patch could not be applied to Casks/parallels.rb.'; return 1 }
    lop -- -d 'Applied patch to Casks/parallels.rb'
  fi
  popd -q
  return 0
}

function installParallels() {
  local inittoolPath='/Applications/Parallels Desktop.app/Contents/MacOS/inittool'
  [[ -f "${inittoolPath}" ]] && return
  indicateActivity -- 'Patching Parallels' patchParallels || return 0
  installCask parallels
  [ -x "${inittoolPath}" ] && indicateActivity -- 'Running Parallels inittool'  ${inittoolPath}  init 
}

function installDMGedBrewCaskPackage() {
  local appName=$1 caskToken=$2 packagePattern=$3 target=${4:-LocalSystem}
  indicateActivity -- "Download ${appName}" ${homebrew_path} fetch --cask ${caskToken} || return 10
  local dmgPath="$(${homebrew_path} --cache --cask ${caskToken})"
  local tmpd="$(mktemp -d -t ${caskToken})"
  pushd -q $tmpd
  hdiutil attach $dmgPath -nobrowse -readonly -mountpoint $tmpd || return
  traps add detach-mount "find '${tmpd}' -type d -mindepth 1 -maxdepth 1 -exec hdiutil detach {} \; >&! /dev/null"
  trap "popd -q; traps call exit; rm -fr '${tmpd}'; traps remove detach-mount" EXIT
  local pkg="$(find $tmpd -name ${packagePattern} | head -n1)"
  [[ -n $pkg ]] || return
  indicateActivity -- "Install ${appName}" installer -package $pkg -target $target
}

function installAdobeAcrobatPro() {
  [[ -d '/Applications/Adobe Acrobat DC' ]] && return
  installDMGedBrewCaskPackage 'Adobe Acrobat Pro' adobe-acrobat-pro '*Installer.pkg'
}

function installSFSymbols() {
  [[ -d '/Applications/SF Symbols.app' ]] && return
  installDMGedBrewCaskPackage 'SF Symbols' sf-symbols 'SF Symbols.pkg'
}

function installSynologyDrive() {
  installDMGedBrewCaskPackage 'Synology Drive' synology-drive '*Synology Drive Client.pkg'
}

function installCasks() {
  lop -y body:h1 -- -i 'Installing Homebrew casks'
  installParallels
  installAdobeAcrobatPro
  installCask rectangle-pro
  if ! isDebug; then
    installCask little-snitch
    installCask sketch
    installCask setapp
    installCask mountain-duck
    installCask unpkg
    installCask whatsapp
    installCask signal
    installSynologyDrive
    installSFSymbols
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
    installBrew tesseract
    installBrew tesseract-lang
    installBrew ocrmypdf
    installBrew php
    installBrew composer
    installBrew curl
    installBrew exiftool
    installBrew ffmpeg
    installBrew gnupg
    installBrew node
    installBrew nmap
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
	  --homebrew-path PATH        Path to Homebrew binary [default: $(getDefaultHomebrewPath)].
	  -d FILE, --logfile FILE     Print log message to logfile instead of stdout.
	  -v, --verbose               Be more verbose.
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
