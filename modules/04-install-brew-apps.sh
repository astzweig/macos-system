#!/usr/bin/env zsh
# vi: ft=zsh

function brewInstall() {
  local identifier="$1"
  local cask="${2:+--cask}"
  indicateActivity ${homebrew_path},install,-q,${cask},${identifier} "Installing ${identifier} ${cask:+ (Cask)}"
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
  indicateActivity patchParallels 'Patching Parallels' || return 0
  installCask parallels
  [ -x "${inittoolPath}" ] && indicateActivity "${inittoolPath}",init 'Running Parallels inittool'
}

function installCasks() {
  lop -y body:h1 -- -i 'Installing Homebrew casks'
  installParallels
  installCask rectangle-pro
  if ! isDebug; then
    installCask little-snitch
    installCask pdfpenpro
    installCask sketch
    installCask synology-drive
    installCask unpkg
    installCask sf-symbols
  fi
}

function installFonts() {
}

function installBrews() {
  lop -y body:h1 -- -i 'Installing Homebrew formulas'
  installBrew mas
  if ! isDebug; then
    installBrew python
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
  pushd -q /
  installBrews
  installCasks
  installFonts
  popd -q
}

function getExecPrerequisites() {
  cmds=(
    [brew]=''
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
    'i: homebrew-path=Whicht Homebrew binary shall be used? # default:'"$(getDefaultHomebrewPath)"
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
