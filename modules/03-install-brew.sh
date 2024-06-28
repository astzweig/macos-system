#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

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

function ensureUserCanRunPasswordlessSudo() {
	local username=$1
	local sudoersFile="/etc/sudoers.d/no-auth-sudo-for-${username}"
	[[ -f ${sudoersFile} ]] && return
	cat <<- SUDOERS > "${sudoersFile}"
	Defaults:${username} !authenticate
	SUDOERS
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
		indicateActivity 'Creating Homebrew user' createHomebrewUser ${homebrew_username} || return 10
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
	chown -R "${username}:admin" ${itemPath}
	chmod u=rwx,go=rx ${itemPath}
}

function ensureHomebrewCacheDirectory() {
	ensureDirectoryWithDefaultMod "${homebrew_cache}"
	runAsHomebrewUser touch "${homebrew_cache}/.cleaned"
}

function ensureHomebrewLogDirectory() {
	ensureDirectoryWithDefaultMod ${homebrew_log}
}

function ensureLocalBinFolder() {
	local folder="/usr/local/bin"
	if [ ! -d "${folder}" ]; then
		mkdir -p "${folder}" 2> /dev/null || {
			lop -- -e 'Could not create directory' -e $folder
			return 10
		}
		chown root:admin "${folder}"
		chmod ug=rwx,o=rx "${folder}"
	fi
}

function getHomebrewRepositoryPath() {
	local uname_machine=$(/usr/bin/uname -m)
	if [[ ${uname_machine} == "arm64" ]]; then
		print -- "/opt/homebrew"
	else
		print "/usr/local/Homebrew"
	fi
}

function createBrewCallerScript() {
	ensureLocalBinFolder
	local username=${homebrew_username}
	local brewCallerPath="/usr/local/bin/brew"
	[ -f "${brewCallerPath}" ] && rm "${brewCallerPath}"
	cat <<- BREWCALLER > ${brewCallerPath}
	#!/usr/bin/env zsh
	if [ "\$(id -un)" != "${username}" ]; then
		echo 'brew will be run as ${username} user.' >&2
		sudo -E -u "${username}" "\$0" "\$@"
		exit \$?
	fi
	export HOMEBREW_CACHE="${homebrew_cache}"
	export HOMEBREW_LOGS="${homebrew_log}"
	export HOMEBREW_CASK_OPTS="--no-quarantine \${HOMEBREW_CASK_OPTS}"
	export HOMEBREW_NO_AUTO_UPDATE=1
	export HOMEBREW_NO_ANALYTICS=1
	export HOMEBREW_NO_ANALYTICS_THIS_RUN=1
	export HOMEBREW_NO_ANALYTICS_MESSAGE_OUTPUT=1
	umask 002
	"$(getHomebrewRepositoryPath)/bin/brew" "\$@"
	BREWCALLER
	chown ${username}:admin ${brewCallerPath}
	chmod ug+x,o-x ${brewCallerPath}
}

function installHomebrewCore() {
	export NONINTERACTIVE=1
	[ ! -d $(getHomebrewRepositoryPath) ] || return
	sudo --preserve-env=NONINTERACTIVE -u "${homebrew_username}" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	[ -d $(getHomebrewRepositoryPath) ]
}

function createLaunchDaemonsPlist() {
	local username=${homebrew_username}
	local launcherName="de.astzweig.macos.launchdaemons.$1"
	local launcherPath="/Library/LaunchDaemons/${launcherName}.plist"
	[[ -f $launcherPath ]] && return
	local brewCommand="$2"
	cat <<- LAUNCHDPLIST > ${launcherPath}
	<?xml version=\"1.0\" encoding=\"UTF-8\"?>
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
	<plist version=\"1.0\">
	<dict>
		<key>Label</key>
		<string>${launcherName}</string>
		<key>ProgramArguments</key>
		<array>
			<string>/usr/local/bin/brew</string>
			<string>${brewCommand}</string>
		</array>
		<key>StartInterval</key>
		<integer>1800</integer>
		<key>UserName</key>
		<string>${username}</string>
		<key>GroupName</key>
		<string>admin</string>
		<key>Umask</key>
		<integer>2</integer>
	</dict>
	</plist>"
	LAUNCHDPLIST
	chown root:wheel ${launcherPath}
	chmod u=rw,go=r ${launcherPath}
	launchctl bootstrap system ${launcherPath}
}

function installHomebrewUpdater() {
	createLaunchDaemonsPlist brew-updater update
	createLaunchDaemonsPlist brew-upgrader upgrade
	return
}

function configure_system() {
	lop -y h1 -- -i 'Install System Homebrew'
	createHomebrewUserIfNeccessary || return 10
	indicateActivity 'Ensure Homebrew user is in admin group' ensureUserIsInAdminGroup ${homebrew_username} || return 11
	indicateActivity 'Ensure Homebrew user can run passwordless sudo' ensureUserCanRunPasswordlessSudo ${homebrew_username} || return 12
	ensureHomebrewCacheDirectory || return 13
	ensureHomebrewLogDirectory || return 14
	indicateActivity 'Install Homebrew core' installHomebrewCore || return 15
	indicateActivity 'Create brew caller script' createBrewCallerScript || return 16
	indicateActivity 'Install Homebrew updater' installHomebrewUpdater || return 17
}

function getExecPrerequisites() {
	cmds=(
		[dscl]=''
		[dseditgroup]=''
		[chown]=''
		[chmod]=''
		[sudo]=''
		[grep]=''
		[git]=''
		[sort]=''
		[awk]=''
		[launchctl]=''
		[sysadminctl]=''
	)
	requireRootPrivileges
}

function getDefaultHomebrewUsername() {
	print -- _homebrew
}

function getDefaultHomebrewCachePath() {
	print -- /Library/Caches/Homebrew
}

function getDefaultHomebrewLogPath() {
	print -- /var/log/Homebrew
}

function getQuestions() {
	questions=(
		'i: homebrew-username=What shall the Homebrew user'\''s username be? # default:'"$(getDefaultHomebrewUsername)"
		'i: homebrew-cache=What shall the Homebrew cache directory be? # default:'"$(getDefaultHomebrewCachePath)"
		'i: homebrew-log=What shall the Homebrew log directory be? # default:'"$(getDefaultHomebrewLogPath)"
	)
}

function getUsage() {
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --homebrew-username NAME --homebrew-cache PATH --homebrew-log PATH

	Create a designated Homebrew user who may not login to the system but is the
	only one able to install homebrew software systemwide. Install Homebrew at
	given PREFIX and make the new Homebrew user the owner of that.

	Options:
	  --homebrew-cache PATH     Path to folder that shall be used as the
	                            cache for Homebrew [default: $(getDefaultHomebrewCachePath)].
	  --homebrew-log PATH       Path to folder that shall be used as the log
	                            directory for Homebrew [default: $(getDefaultHomebrewLogPath)].
	  --homebrew-username NAME  Username of the designated Homebrew user.
	                            [default: $(getDefaultHomebrewUsername)].
	  -d FILE, --logfile FILE   Print log message to logfile instead of stdout.
	  -v, --verbose             Be more verbose.
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
