#!/usr/bin/env zsh
# vi: ft=zsh

export HOMEBREW_NO_ANALYTICS_THIS_RUN=1
export HOMEBREW_NO_ANALYTICS_MESSAGE_OUTPUT=1

function doesUserExist() {
  local username=$1
  dscl . -list /Users | grep "^${username}$" 2> /dev/null >&2
}

function runAsUser() {
  local username=$1
  shift
  sudo -Hu "${username}" "${@}"
}

function runAsHomebrewUser() {
 runAsUser ${homebrew_username} "$@"
}

function ensureUserIsInAdminGroup() {
  local username=$1
  dseditgroup -o edit -a "${username}" -t user admin
}

function ensureUserCannotRunSudo() {
  local username=$1
  local sudoersFile="/etc/sudoers.d/disallow-sudo-for-${username}"
  [[ -f ${sudoersFile} ]] && return
  print -- "Defaults:${username} !authenticate
  ${username} ALL=(ALL) !ALL" > "${sudoersFile}"
  chown root:wheel "${sudoersFile}" || return 10
  chmod u=rw,g=r,o= "${sudoersFile}" || return 20
}

function getFirstFreeRoleAccountID() {
  dscl . -list '/Users' UniqueID | grep '_.*' | sort -n -k2 | awk -v i=401 '$2>200 && $2<401 {if(i < $2) { print i; nextfile} else i=$2+1;}'
}

function createHomebrewUser() {
  local username=$1
  local userID=`getFirstFreeRoleAccountID`
  sysadminctl -addUser "${username}" -fullName "Homebrew User" -shell /usr/bin/false -home '/var/empty' -roleAccount -UID "${userID}" > /dev/null 2>&1
}

function createHomebrewUserIfNeccessary() {
  if ! doesUserExist ${homebrew_username}; then
    lop -y body:warn -y body -- -i "No Homebrew user named ${homebrew_username} found." -i 'Will create user.'
    indicateActivity createHomebrewUser,${homebrew_username} 'Creating Homebrew user' || return 10
  else
    lop -y body:note -y body -- -i "Homebrew user named ${homebrew_username} already exists." -i 'Skipping.'
  fi
}

function ensureDirectoryWithDefaultMod() {
  local itemPath=${1}
  mkdir -p ${itemPath}
  ensureHomebrewOwnershipAndPermission ${itemPath}
}

function ensureHomebrewOwnershipAndPermission() {
  local itemPath=${1}
  local username=${homebrew_username}
  [[ -f ${itemPath} || -d ${itemPath} ]] || return 1
  chown "${username}:admin" ${itemPath}
  chmod ug+rwx,o-w ${itemPath}
}

function ensureInstallPrefix() {
  if [ ! -d "${INSTALL_PREFIX}" ]; then
    mkdir -p "${INSTALL_PREFIX}"
    chown root:wheel "${INSTALL_PREFIX}"
  fi
}

function makeDirsGroupWritableIfExist() {
  local dir=
  local directories=(bin etc include sbin share opt var Frameworks etc/bash_completion.d lib/pkgconfig share/aclocal share/doc  share/info share/locale share/man share/man/man1 share/man/man2 share/man/man3 share/man/man4 share/man/man5 share/man/man6 share/man/man7 share/man/man8 var/log var/homebrew var/homebrew/linked bin/brew)

  for dir in ${directories}; do
    [[ ! -d "${dir}" ]] && continue
    ensureHomebrewOwnershipAndPermission ${dir}
  done
}

function ensureZSHDirectories() {
  local dir=
  local directories=(share/zsh share/zsh/site-functions)
  for dir in ${directories}; do
    ensureDirectoryWithDefaultMod ${dir}
    chmod go-w ${dir}
  done
}

function ensureHomebrewDirectories() {
  local dir=
  local directories=(bin etc include lib sbin share var opt Homebrew var/homebrew var/homebrew/linked Cellar Caskroom Frameworks)
  for dir in ${directories}; do
    ensureDirectoryWithDefaultMod ${dir}
  done
}

function ensureHomebrewCacheDirectory() {
  ensureDirectoryWithDefaultMod "${homebrew_cache}"
  runAsHomebrewUser touch "${homebrew_cache}/.cleaned"
}

function ensureHomebrewLogDirectory() {
  ensureDirectoryWithDefaultMod ${homebrew_log}
}

function fixInstallPrefixPermissions() {
  pushd -q ${dirPath}
  makeDirsGroupWritableIfExist
  ensureZSHDirectories
  ensureHomebrewDirectories
  popd -q
}

function configureInstallPrefix() {
  local dirPath=$1
  if [[ -d "${dirPath}" ]]; then
    lop -y body -- -d "Install prefix at ${dirPath} already exists. Will correct permissions of possible enclosed folders."
    indicateActivity fixInstallPrefixPermissions 'Correct permissions of possible enclosed folders'
  else
    lop -y body -- -d "Install prefix at ${dirPath} does not exist. Will create it."
    indicateActivity createInstallPrefix 'Creating install prefix'
  fi
}

function createInstallPrefix() {
  mkdir -p ${dirPath} 2> /dev/null || {
    lop -- -e 'Could not create directory' -e $dirPath
    return 10
  }
  chown root:wheel "${dirPath}"
  chmod 744 "${dirPath}"
}

function downloadHomebrew() {
  cd "${homebrew_prefix}/Homebrew" > /dev/null || return 10
  [ -d ".git" ] && return 11
  runAsHomebrewUser git init -q
  runAsHomebrewUser git config remote.origin.url "${git_homebrew_remote}"
  runAsHomebrewUser git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  runAsHomebrewUser git config core.autocrlf false
  runAsHomebrewUser git config --replace-all homebrew.analyticsmessage false
  runAsHomebrewUser git config --replace-all homebrew.caskanalyticsmessage false
  runAsHomebrewUser git fetch --quiet --force --depth 1 origin > /dev/null
  runAsHomebrewUser git fetch --quiet --force --tags --depth 1 origin > /dev/null
  runAsHomebrewUser git reset --hard origin/master
}

function createBrewCallerScript() {
  local username=${homebrew_username}
  local brewCallerPath="${homebrew_prefix}/Homebrew/bin/brew_caller"
  print -- "#!/usr/bin/env zsh
  if [ \"\$(id -un)\" != \"${username}\" ]; then
    echo 'brew will be run as ${username} user.' >&2
    sudo -E -u \"${username}\" \"\$0\" \"\$@\"
    exit \$?
  fi
  export HOMEBREW_CACHE=\"${homebrew_cache}\"
  export HOMEBREW_LOGS=\"${homebrew_log}\"
  export HOMEBREW_CASK_OPTS=\"--no-quarantine \${HOMEBREW_CASK_OPTS}\"
  export HOMEBREW_NO_AUTO_UPDATE=1
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_ANALYTICS_THIS_RUN=1
  export HOMEBREW_NO_ANALYTICS_MESSAGE_OUTPUT=1
  \"${homebrew_prefix}/Homebrew/bin/brew\" \"\$@\"" > ${brewCallerPath}
  chown ${username}:admin ${brewCallerPath}
  chmod ug+x ${brewCallerPath}
  runAsHomebrewUser ln -sf ${homebrew_prefix}/Homebrew/bin/brew_caller "${homebrew_prefix}/bin/brew"
}

function installHomebrewCore() {
  runAsHomebrewUser mkdir -p "${homebrew_prefix}/Homebrew/Library/Taps/homebrew/homebrew-core" || return 10
  pushd -q "${homebrew_prefix}/Homebrew/Library/Taps/homebrew/homebrew-core"
  [ -d ".git" ] && return
  runAsHomebrewUser git init -q
  runAsHomebrewUser git config remote.origin.url "${git_homebrew_core_remote}"
  runAsHomebrewUser git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  runAsHomebrewUser git config core.autocrlf false
  runAsHomebrewUser git fetch --quiet --depth 1 --force origin 'refs/heads/master:refs/remotes/origin/master' > /dev/null
  runAsHomebrewUser git remote set-head origin --auto > /dev/null
  runAsHomebrewUser git reset --hard origin/master
}

function createLaunchDaemonsPlist() {
  local username=${homebrew_username}
  local launcherName="de.astzweig.macos.launchdaemons.$1"
  local launcherPath="/Library/LaunchDaemons/${launcherName}.plist"
  local brewCommand="$2"
  echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
  <dict>
    <key>Label</key>
    <string>${launcherName}</string>
    <key>Program</key>
    <string>${homebrew_prefix}/bin/brew</string>
    <key>ProgramArguments</key>
    <array>
      <string>${brewCommand}</string>
    </array>
    <key>StartInterval</key>
    <integer>1800</integer>
    <key>UserName</key>
    <string>${username}</string>
    <key>GroupName</key>
    <string>admin</string>
  </dict>
</plist>" > "${launcherPath}"
  chown root:wheel ${launcherPath}
  chmod u=rw,go=r ${launcherPath}
}

function installHomebrewUpdater() {
  createLaunchDaemonsPlist brew-updater update
  createLaunchDaemonsPlist brew-upgrader upgrade
}

function tapHomebrewCask() {
  brew tap homebrew/cask ${git_homebrew_cask_remote} >&! /dev/null
}

function tapHomebrewCaskFonts() {
  brew tap homebrew/cask-fonts ${git_homebrew_font_remote} >&! /dev/null
}

function configure_system() {
  createHomebrewUserIfNeccessary || return 10
  indicateActivity ensureUserIsInAdminGroup,${homebrew_username} 'Ensure Homebrew user is in admin group' || return 11
  indicateActivity ensureUserCannotRunSudo,${homebrew_username} 'Ensure Homebrew user can not run sudo' || return 12
  configureInstallPrefix ${homebrew_prefix} || return 13
  ensureHomebrewCacheDirectory || return 14
  ensureHomebrewLogDirectory || return 15
  indicateActivity downloadHomebrew 'Downloading Homebrew' || return 16
  indicateActivity createBrewCallerScript 'Create brew caller script' || return 17
  indicateActivity installHomebrewCore 'Install Homebrew core' || return 18
  indicateActivity installHomebrewUpdater 'Install Homebrew updater' || return 19
  pushd -q /
  indicateActivity tapHomebrewCask 'Tapping homebrew/cask' || return 20
  indicateActivity tapHomebrewCaskFonts 'Tapping homebrew/cask-fonts' || return 21
  popd -q
}

function checkPrerequisites() {
  local -A cmds=(
    [docopts]='(with -f option supported)'
    [dscl]=''
    [dseditgroup]=''
    [chown]=''
    [chmod]=''
    [sudo]=''
    [grep]=''
    [sort]=''
    [awk]=''
    [sysadminctl]=''
  )
  test "`id -u`" -eq 0 || { lop -- -e 'This module requires root access. Please run as root.'; return 11 }
  checkCommands
}

function getDefaultHomebrewUsername() {
  print -- _homebrew
}

function getDefaultHomebrewPrefix() {
  print -- /usr/local
}

function getDefaultHomebrewCachePath() {
  print -- /Library/Caches/Homebrew
}

function getDefaultHomebrewLogPath() {
  print -- /var/log/Homebrew
}

function getDefaultGitHomebrewURL() {
  print -- ${HOMEBREW_BREW_GIT_REMOTE:-https://github.com/Homebrew/brew.git}
}

function getDefaultGitHomebrewCoreURL() {
  print -- ${HOMEBREW_BREW_CORE_GIT_REMOTE:-https://github.com/Homebrew/homebrew-core.git}
}

function getDefaultGitHomebrewCaskURL() {
  print -- ${HOMEBREW_BREW_CASK_GIT_REMOTE:-https://github.com/Homebrew/homebrew-cask.git}
}

function getDefaultGitHomebrewCaskFontsURL() {
  print -- ${HOMEBREW_BREW_CASK_FONTS_GIT_REMOTE:-https://github.com/Homebrew/homebrew-cask-fonts.git}
}

function getQuestions() {
  questions=(
    'i: homebrew-username=What shall the Homebrew user'\''s username be? # default:'"$(getDefaultHomebrewUsername)"
    'i: homebrew-prefix=What shall the Homebrew prefix be? # default:'"$(getDefaultHomebrewPrefix)"
    'i: homebrew-cache=What shall the Homebrew cache directory be? # default:'"$(getDefaultHomebrewCachePath)"
    'i: homebrew-log=What shall the Homebrew log directory be? # default:'"$(getDefaultHomebrewLogPath)"
    'i: git-homebrew-remote=Which Git repository shall be used to install Homebrew from? # default:'"$(getDefaultGitHomebrewURL)"
    'i: git-homebrew-core-remote=Which Git repository shall be used to install Homebrew core from? # default:'"$(getDefaultGitHomebrewCoreURL)"
    'i: git-homebrew-cask-remote=Which Git repository shall be used to install Homebrew cask from? # default:'"$(getDefaultGitHomebrewCaskURL)"
    'i: git-homebrew-font-remote=Which Git repository shall be used to install Homebrew cask-fonts from? # default:'"$(getDefaultGitHomebrewCaskFontsURL)"
  )
}

function getUsage() {
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --homebrew-prefix PREFIX --homebrew-username NAME --homebrew-cache PATH --homebrew-log PATH --git-homebrew-remote URL --git-homebrew-core-remote URL --git-homebrew-cask-remote URL --git-homebrew-font-remote URL
	
	Create a designated Homebrew user who may not login to the system but is the
	only one able to install homebrew software systemwide. Install Homebrew at
	given PREFIX and make the new Homebrew user the owner of that.
	
	Options:
	  --homebrew-prefix PREFIX        Path to folder that shall be the prefix of
	                                  the system wide Homebrew installation [default: $(getDefaultHomebrewPrefix)].
	  --git-homebrew-remote URL       Git URL to the Homebrew repository [default: $(getDefaultGitHomebrewURL)].
	  --git-homebrew-core-remote URL  Git URL to the Homebrew core repository [default: $(getDefaultGitHomebrewCoreURL)].
	  --git-homebrew-cask-remote URL  Git URL to the Homebrew cask repository [default: $(getDefaultGitHomebrewCaskURL)].
	  --git-homebrew-font-remote URL  Git URL to the Homebrew cask-fonts repository [default: $(getDefaultGitHomebrewCaskFontsURL)].
	  --homebrew-cache PATH           Path to folder that shall be used as the
	                                  cache for Homebrew [default: $(getDefaultHomebrewCachePath)].
	  --homebrew-log PATH             Path to folder that shall be used as the log
	                                  directory for Homebrew [default: $(getDefaultHomebrewLogPath)].
	  --homebrew-username NAME        Username of the designated Homebrew user.
	                                  [default: $(getDefaultHomebrewUsername)].
	  -d FILE, --logfile FILE         Print log message to logfile instead of stdout.
	  -v, --verbose                   Be more verbose.
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