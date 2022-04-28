#!/usr/bin/env zsh
# vi: ft=zsh

function getComputerName() {
  local moduleAnswer
  local computerName="`scutil --get ComputerName 2> /dev/null`"
  getModuleAnswerByKeyRegEx '_hostname$' && computerName=$moduleAnswer
  print -- $computerName
}

function getDefaultFullname() {
  local computerName="`getComputerName`"
  lop -- -d 'Default full name based on current computer name is:' -d "$computerName"
  print "${computerName}"
}

function getDefaultUsername() {
  local username="`getDefaultFullname | tr '[:upper:]' '[:lower:]' | tr -C '[:alnum:]\n' '-'`"
  lop -- -d 'Default username based on current computer name is:' -d "$username"
  print "${username}"
}

function isAPFSFilesystem() {
  [[ $(diskutil info / | awk 'sub(/File System Personality: /,""){print $0}') = *APFS* ]]
}

function getUsersWithSecureToken() {
  local username uuid
  for uuid in ${$(diskutil apfs listUsers / | awk '/\+\-\-/ {print $2}')}; do
    username="$(dscl . -search /Users GeneratedUID ${uuid} | awk 'NR==1{print $1}')"
    checkSecureTokenForUser ${username} && secureTokenUsers+=("${username}")
  done
}

function getDefaultUserPictures() {
  pushd -q '/Library/User Pictures'
  defaultUserPictures=("${(@f)$(find -E . -type f -iregex '.*\.(tif|png|jpeg|jpg)' | abbreviatePaths)}")
  popd -q
}

function convertPathToDefaultPicture() {
  local resolved=''
  lop -- -d 'Converting path' -d "${filevault_picture}" -d 'to default picture path if necessary.'
  if [ -r "${filevault_picture}" ]; then
    lop -- -d 'Path seems to be a valid path already. Skipping conversion.'
    return
  fi
  pushd -q '/Library/User Pictures'
  resolved="`find "$_" -type f -path "*${filevault_picture}" 2> /dev/null`"
  lop -- -d 'Resolved path is' -d "${resolved}"
  popd -q
  [ -n "${resolved}" -a -r "${resolved}" ] && filevault_picture="${resolved}"
}

function _isPathToPicture() {
  local filevault_picture=$1
  convertPathToDefaultPicture
  [ -r "${filevault_picture}" ] || { lop -- -d 'Resolved path is not a valid path. Returning.'; return 10 }
  [[ "${filevault_picture:e:l}" =~ (tif|png|jpeg|jpg) ]] || return 11
}

function isPathToPicture() {
  indicateActivity -- "Verifying $1 as picture path" _isPathToPicture $1
}

function _checkSecureTokenForUser() {
  local u=$1
  sysadminctl -secureTokenStatus "${u}" 2>&1 | grep ENABLED >&! /dev/null
}

function checkSecureTokenForUser() {
  local u=$1
  indicateActivity -- "Checking if user $u has a secure token set" _checkSecureTokenForUser $u
}

function _checkUserPassword() {
  local username=$1 password=$2
  dscl . -authonly ${username} ${password} >&! /dev/null
}

function checkSecureTokenUserPassword() {
  indicateActivity -- "Checking password for user ${secure_token_user_username}" _checkUserPassword ${secure_token_user_username} ${secure_token_user_password}
}

function checkFileVaultUserPassword() {
  indicateActivity -- "Checking password for user ${filevault_username}" _checkUserPassword ${filevault_username} ${filevault_password}
}

function _doesFileVaultUserExist() {
  dscl . -list /Users | grep "${filevault_username}" >&! /dev/null
}

function doesFileVaultUserExist() {
  indicateActivity -- "Checking if ${filevault_username} already exists" _doesFileVaultUserExist
}

function _createFileVaultUser() {
  local un=${filevault_username} fn=${filevault_fullname} pw=${filevault_password} result=
  lop -- -d 'Creating FileVault user' -d "${un}"
  sysadminctl -addUser ${un} -fullName ${fn} -shell /usr/bin/false -home /var/empty -password ${pw} -picture ${filevault_picture}
  result=$?
  lop -- -d 'Return value of sysadminctl is ' -d "$?"
  return $result
}

function createFileVaultUser() {
  indicateActivity -- "Creating FileVault user ${filevault_username}" _createFileVaultUser
}

function _configureFileVaultUser() {
  local un=${filevault_username}
  dscl . -create "/Users/${un}" IsHidden 1
  chsh -s /usr/bin/false "${un}" >&! /dev/null
}

function configureFileVaultUser() {
  indicateActivity -- "Configuring FileVault user ${filevault_username}" _configureFileVaultUser
}

function configureSecureToken() {
  local un=${filevault_username} up=${filevault_password}
  local stun=${secure_token_user_username} stup=${secure_token_user_password}
  sysadminctl -secureTokenOn "${un}" -password "${up}" -adminUser "${stun}" -adminPassword "${stup}"
}

function canUserUnlockDisk() {
  local username=$1
  for fdeuser in ${(f)"$(fdesetup list | cut -d',' -f1)"}; do
    [[ ${fdeuser} = ${username} ]] && return
  done
  return 1
}

function getFDESetupXMLForUser() {
  local username="${1}" password="${2}"
  cat <<- XML
	<?xml version="1.0" encoding=\"UTF-8\"?>
	<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
	<plist version=\"1.0\">
	<dict>
	<key>Username</key>
	<string>${username}</string>
	<key>Password</key>
	<string>${password}</string>
	</dict>
	</plist>
	XML
}

function _enableFileVaultForSecureTokenUser() {
  local username="${1}" password="${2}"
  getFDESetupXMLForUser "${username}" "${password}" | fdesetup enable -inputplist
}

function enableFileVaultForSecureTokenUser() {
  fdesetup isactive >&! /dev/null && return
  indicateActivity -- "Enable FileVault for secure token" _enableFileVaultForSecureTokenUser ${secure_token_user_username} ${secure_token_user_password}
}

function _allowUserToUnlockDisk() {
  local username="${1}" password="${2}"
  getFDESetupXMLForUser ${username} ${password} | fdesetup add -inputplist
}

function allowFileVaultUserToUnlockDisk() {
  indicateActivity -- "Allow FileVault user to unlock disk" _allowUserToUnlockDisk ${filevault_username} ${filevault_password}
}

function _allowOnlyFileVaultUserToUnlock() {
  local fdeuser
  for fdeuser in ${(f)"$(fdesetup list | cut -d',' -f1)"}; do
   [[ ${fdeuser} != ${filevault_username} ]] && fdesetup remove -user "${fdeuser}"
  done
  return 0
}

function allowOnlyFileVaultUserToUnlock() {
  indicateActivity -- "Disallow everyone else from unlocking disk" _allowOnlyFileVaultUserToUnlock
}

function configure_system() {
  lop -y h1 -- -i 'Setup FileVault System'
  checkSecureTokenForUser "${secure_token_user_username}" || { lop -- -e 'The provided secure token user has no secure token.'; return 10 }
  checkSecureTokenUserPassword || { lop -- -e 'The secure token user password is incorrect.'; return 11 }
  indicateActivity -- "Resolving path of picture ${filevault_picture}" convertPathToDefaultPicture
  isPathToPicture "${filevault_picture}" || { lop -- -e 'The provided FileVault user picture is not a valid path to a TIF, PNG or JPEG file.'; return 12 }

  if doesFileVaultUserExist; then
    checkFileVaultUserPassword || { lop -- -e 'The FileVault user password is incorrect.'; return 13 }
  else
    createFileVaultUser
  fi
  configureFileVaultUser
  enableFileVaultForSecureTokenUser
  checkSecureTokenForUser "${filevault_username}" || configureSecureToken
  canUserUnlockDisk ${filevault_username} || allowFileVaultUserToUnlockDisk
  allowOnlyFileVaultUserToUnlock "${filevault_username}"
}

function getHelpPrerequisites() {
  cmds=(
    [tr]=''
    [scutil]=''
  )
  addDocoptsToCmds
}

function getQuestionsPrerequisites() {
  cmds=(
    [find]=''
    [dscl]=''
    [dseditgroup]=''
    [awk]=''
    [diskutil]=''
    [sysadminctl]=''
  )
  isAPFSFilesystem || { lop -- -e 'This module requires an APFS filesystem.'; return 10 }
}

function getExecPrerequisites() {
  cmds=(
    [cut]=''
    [cat]=''
    [fdesetup]=''
    [base64]=''
    [dsimport]=''
  )
  requireRootPrivileges
}

function getQuestions() {
  local secureTokenUsers=() defaultUserPictures=()
  local defaultUsername="`getDefaultUsername`" defaultFullname="`getDefaultFullname`"
  getUsersWithSecureToken
  getDefaultUserPictures
  local defaultUsernameHint= defaultFullnameHint=
  [ -n "${defaultUsername}" ] && defaultUsernameHint="default:${defaultUsername};"
  [ -n "${defaultFullname}" ] && defaultFullnameHint="default:${defaultFullname};"
  questions=(
    'i: filevault-fullname=What shall the FileVault user'\''s full name be? # '"${defaultFullnameHint}"
    'i: filevault-username=What shall the FileVault user'\''s username be? # '"${defaultUsernameHint}"
    'p: filevault-password=What shall the FileVault user'\''s password be?'
    's: filevault-picture=Select a picture for FileVault user or enter the path to your own picture # validator:'"${cmdPath}"',is-picture;choose from:'"${(j.,.)defaultUserPictures};"
    's: secure-token-user-username=Which user with a secure token shall be used? # choose from:'"${(j.,.)secureTokenUsers};"
    'p: secure-token-user-password=What is the secure token user'\''s password?'
  )
}

function preQuestionHook() {
  if [[ "${is_picture}" = true ]]; then
    isPathToPicture ${pathstr}
    exit $?
  fi
}

function getUsage() {
  local cmdName=$1 text='' varname=
  local defaultUsername="`getDefaultUsername`" defaultFullname="`getDefaultFullname`"
  for varname in defaultUsername defaultFullname; do
    local ${varname}Str=
    [ -n "${(P)varname}" ] && local ${varname}Str=" [default: ${(P)varname}]"
  done
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName is-picture <pathstr>
	  $cmdName [-v] [-d FILE] --filevault-fullname NAME --filevault-username NAME --filevault-password PASSWORD --filevault-picture PATH_TO_PIC --secure-token-user-username NAME --secure-token-user-password PASSWORD
	
	Create a designated FileVault user who may not login to the system but is the
	only one able to unlock the disk. That way a secure password can be used to
	unlock the disk as opposed to macOS standard, where each user is allowed to
	unlock the disk with his password that may or may not be secure (in terms of
	length and randomness).
	
	Options:
	  --filevault-fullname NAME              Full name of the designated FileVault user. An
	                                         existing FileVault user will be renamed to that
	                                         name${defaultFullnameStr}.
	  --filevault-username NAME              Username of the designated FileVault user. An
	                                         existing FileVault user will be renamed to that
	                                         name${defaultUsernameStr}.
	  --filevault-password PASSWORD          Password of the designated FileVault user. The password
	                                         an existing FileVault user will not be changed.
	  --filevault-picture PATH_TO_PIC        The path to the picture that shall be made the FileVault
	                                         user picture. The picture of an existing FileVault user
	                                         will be updated.
	  --secure-token-user-username NAME      The username of an user with a secure token.
	  --secure-token-user-password PASSWORD  The password of the secure token user.
	  -d FILE, --logfile FILE                Print log message to logfile instead of stdout.
	  -v, --verbose                          Be more verbose.
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
