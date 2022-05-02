#!/usr/bin/env zsh
# vi: ft=zsh

function getQuestionsPrerequisites() {
  cmds=(
    [systemsetup]=''
  )
  requireRootPrivileges
}

function getExecPrerequisites() {
  cmds=(
    [osascript]=''
    [scutil]=''
    [systemsetup]=''
    [nvram]=''
    [pmset]=''
    [defaults]=''
    [/usr/libexec/ApplicationFirewall/socketfilterfw]=''
    [launchctl]=''
  )
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
 indicateActivity -- 'Quitting System Preferences' osascript -e 'tell application "System Preferences" to quit'
}

function setComputerName() {
  scutil --set ComputerName "${hostname}"
  scutil --set HostName "${hostname}"
  scutil --set LocalHostName "${hostname}"
  systemsetup -setcomputername "${hostname}"
  systemsetup -setlocalsubnetname "${hostname}"
}

function configureComputerHostname() {
  local currentComputerName="`scutil --get ComputerName`"
  if [[ "${currentComputerName}" != "${hostname}" ]]; then
    lop -- -i 'Hostname of computer has not been set.' -i "Will set to ${hostname}."
    indicateActivity -- 'Set computer name' setComputerName
  else
    lop -- -i 'Hostname of computer seems to have already been set. Skipping.' -i "Hostname: $currentComputerName"
  fi
}

function configureBasicSystem(){
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
}

function configurePowerManagement() {
  cmd=(pmset -a)
  ${cmd} displaysleep 0
  ${cmd} disksleep 0
  ${cmd} sleep 0
  ${cmd} womp 0
  ${cmd} acwake 0
  ${cmd} proximitywake 0
  ${cmd} destroyfvkeyonstandby 1
  pmset -b acwake 1
  ${cmd} lidwake 1
  ${cmd} halfdim 1
  ${cmd} powernap 1
  ${cmd} hibernatemode 0
}

function configureLoginWindow() {
  cmd=(defaults write '/Library/Preferences/com.apple.loginwindow')
  ${cmd} DisableFDEAutoLogin -bool true
  ${cmd} SHOWFULLNAME -bool false
  ${cmd} AdminHostInfo -string HostName
  ${cmd} GuestEnabled -bool false
}

function configureMacOSFirewall() {
  cmd=(/usr/libexec/ApplicationFirewall/socketfilterfw)
  ${cmd} --setglobalstate on
  ${cmd} --setblockall off
  ${cmd} --setstealthmode on
  ${cmd} --setallowsigned on
  ${cmd} --setallowsignedapp on
}

function configure_system() {
  lop -y h1 -- -i 'Configure System Settings'
  quitSystemPreferences
  configureComputerHostname
  indicateActivity -- 'Configuring systemsetup and nvram' configureBasicSystem
  indicateActivity -- 'Configuring power management' configurePowerManagement
  indicateActivity -- 'Configuring login window' configureLoginWindow
  indicateActivity -- 'Configure global umask' launchctl config user umask 027
  indicateActivity -- 'Configure macOS firewall' configureMacOSFirewall
}

function getUsage() {
  local cmdName=$1 text=''
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
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
  print -- ${text}
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  test -f "${ASTZWEIG_MACOS_SYSTEM_LIB}" || { echo 'This module requires macos-system library. Please run again with macos-system library provieded as a path in ASTZWEIG_MACOS_SYSTEM_LIB env variable.'; return 10 }
  source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
  module_main $0 "$@"
fi
