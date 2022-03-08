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
  test "`id -u`" -eq 0 || { lop -e 'This module requires root access. Please run as root.'; return 11 }
  checkCommands
}

function getQuestions() {
  local timezones
  timezones="`systemsetup -listtimezones | tail -n +2 | awk '{print $1}' | paste -sd, -`"
  questions=(
    'i: hostname=What shall the hostname of this host be?' 
    's: timezone=What shall the timezone of this host be? # choose from:'"${timezones};"
  )
}

function quitSystemPreferences() {
  lop -d 'Quitting System Preferences App'
  osascript -e 'tell application "System Preferences" to quit'
}

function configureComputerHostname() {
  lop -i 'Configuring computer hostname.'
  lop -d "Current hostname: `scutil --get ComputerName`"
  if [[ "`scutil --get ComputerName`" != "${hostname}" ]]; then
    lop -d 'Hostname of computer has not been set.' -d "Current hostname: `scutil --get ComputerName`"
  
    scutil --set ComputerName "${hostname}"
    scutil --set HostName "${hostname}"
    systemsetup -setcomputername "${hostname}" > /dev/null 2>&1
    systemsetup -setlocalsubnetname "${hostname}" > /dev/null 2>&1
  else
    lop -d 'Hostname of computer seems to have already been set. Skipping.' -d "Hostname: `scutil --get ComputerName`"
  fi
}

function configureBasicSystem(){
  lop --no-newline -i 'Configuring systemsetup and nvram...'
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
  lop -i 'done'
  
}

function configurePowerManagement() {
  lop --no-newline -i 'Configuring power management...'
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
  lop -i 'done'
}

function configureLoginWindow() {
  lop --no-newline -i 'Configuring login window...'
  cmd=(defaults write '/Library/Preferences/com.apple.loginwindow')
  ${cmd} DisableFDEAutoLogin -bool true
  ${cmd} SHOWFULLNAME -bool false
  ${cmd} AdminHostInfo -string HostName
  ${cmd} GuestEnabled -bool false
  lop -i 'done'
}

function configure_system() {
  quitSystemPreferences
  configureComputerHostname
  configureBasicSystem
  configurePowerManagement
  configureLoginWindow

  lop -i 'Configuring global umask'
  launchctl config user umask 027
}

function getUsage() {
  local cmdName=$1 text=''
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions
	  $cmdName [-v] [-d FILE] --hostname NAME --timezone ZONE
	
	Set energy, basic network and host preferences.
	
	Options:
	  --hostname NAME  Set NAME as current host's host name.
	  --timezone ZONE  Set ZONE as current host's timezone [default: Europe/Berlin].
	  -d FILE, --logfile FILE  Print log message to logfile instead of stdout.
	  -v, --verbose            Be more verbose.
	----
	$cmdName 0.1.0
	Copyright (C) 2022 Rezart Qelibari, Astzweig GmbH & Co. KG
	License EUPL-1.2. There is NO WARRANTY, to the extent permitted by law.
	USAGE
  print ${text}
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  test -f "${ASTZWEIG_MACOS_SYSTEM_LIB}" || { echo 'This module requires macos-system library. Please run again with macos-system library provieded as a path in ASTZWEIG_MACOS_SYSTEM_LIB env variable.'; return 10 }
  source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
  module_main $0 "$@"
fi
