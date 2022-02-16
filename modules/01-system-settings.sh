#!/usr/bin/env zsh
# vi: ft=zsh

function checkPrerequisites() {
  local -A cmds=(
    [docopts]='(with -f option supported)'
    [osascript]=''
    [scutil]=''
    [systemsetup]=''
    [nvram]=''
    [pmset]=''
    [defaults]=''
    [launchctl]=''
  )
  test "`id -u`" -eq 0 || { lop error 'This module requires root access. Please run as root.'; return 11 }
  checkCommands
}

function showQuestions() {
  local timezones questions question
  timezones="`systemsetup -listtimezones | tail -n +2 | awk '{print $1}' | paste -sd, -`"
  questions=(
    'i: hostname=What shall the hostname of this host be?' 
    's: timezone=What shall the timezone of this host be? # choose from:'"${timezones};"
  )
  for question in ${questions}; do
    hio info "${question}"
  done
}

function quitSystemPreferences() {
  lop debug 'Quitting System Preferences App'
  osascript -e 'tell application "System Preferences" to quit'
}

function configureComputerHostname() {
  lop info 'Configuring computer hostname.' debug "Current hostname: `scutil --get ComputerName`"
  if [[ "`scutil --get ComputerName`" != "${hostname}" ]]; then
    lop debug 'Hostname of computer has not been set.' debug "Current hostname: `scutil --get ComputerName`"
  
    scutil --set ComputerName "${hostname}"
    scutil --set HostName "${hostname}"
    systemsetup -setcomputername "${hostname}" > /dev/null 2>&1
    systemsetup -setlocalsubnetname "${hostname}" > /dev/null 2>&1
  else
    lop debug 'Hostname of computer seems to have already been set. Skipping.' debug "Hostname: `scutil --get ComputerName`"
  fi
}

function configureBasicSystem(){
  lop -n info 'Configuring systemsetup and nvram...'
  # Disable the sound effects on boot
  nvram SystemAudioVolume=" "
  
  systemsetup -settimezone "${timezone}" >&! /dev/null
  systemsetup -setusingnetworktime on >&! /dev/null
  systemsetup -setnetworktimeserver 'time.apple.com' >&! /dev/null
  systemsetup -setsleep never >&! /dev/null
  systemsetup -setwakeonnetworkaccess off >&! /dev/null
  systemsetup -setrestartfreeze on >&! /dev/null
  systemsetup -f -setremotelogin off >&! /dev/null
  systemsetup -setremoteappleevents off >&! /dev/null
  lop success 'done'
  
}

function configurePowerManagement() {
  lop -n info 'Configuring power management...'
  cmd=(pmset -a)
  ${cmd} displaysleep 0
  ${cmd} disksleep 0
  ${cmd} sleep 0
  ${cmd} womp 0
  ${cmd} acwake 0
  ${cmd} proximitywake 0
  ${cmd} destroyfvkeyonstandby 1 > /dev/null
  pmset -b acwake 1
  ${cmd} lidwake 1
  ${cmd} halfdim 1
  ${cmd} powernap 1
  ${cmd} hibernatemode 0
  lop success 'done'
}

function configureLoginWindow() {
  lop -n info 'Configuring login window...'
  cmd=(defaults write '/Library/Preferences/com.apple.loginwindow')
  ${cmd} DisableFDEAutoLogin -bool true
  ${cmd} SHOWFULLNAME -bool false
  ${cmd} AdminHostInfo -string HostName
  ${cmd} GuestEnabled -bool false
  lop success 'done'
}

function main() {
  autoloadZShLib || return
  checkPrerequisites || return
  eval "`docopts -f -V - -h - : "$@" <<- USAGE
	Usage:
	  $0 show-questions
	  $0 [-v] [-d FILE] --hostname NAME --timezone ZONE
	
	Set energy, basic network and host preferences.

	Options:
	  --hostname NAME  Set NAME as current host's host name.
	  --timezone ZONE  Set ZONE as current host's timezone [default: Europe/Berlin].
	  -d FILE, --logfile FILE  Print log message to logfile instead of stdout.
	  -v, --verbose            Be more verbose.
	----
	$0 0.1.0
	Copyright (C) 2022 Rezart Qelibari, Astzweig GmbH & Co. KG
	License EUPL-1.2. There is NO WARRANTY, to the extent permitted by law.
	USAGE`"
  [ $# -eq 0 ] && return
  configureLogging
  [ "${show_questions}" = true ] && { showQuestions; return }
  
  quitSystemPreferences
  configureComputerHostname
  configureBasicSystem
  configurePowerManagement
  configureLoginWindow
  
  lop info 'Configuring global umask'
  launchctl config user umask 027
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  test -f "${ASTZWEIG_MACOS_SYSTEM_LIB}" || { echo 'This module requires macos-system library. Please run again with macos-system library provieded as a path in ASTZWEIG_MACOS_SYSTEM_LIB env variable.'; return 10 }
  source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
  main "$@"
fi
