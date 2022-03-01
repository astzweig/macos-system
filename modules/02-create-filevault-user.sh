#!/usr/bin/env zsh

function getDefaultFullname() {
  local computerName="`scutil --get ComputerName 2> /dev/null`"
  lop debug 'Default full name based on current computer name is: '"$computerName"
  print "${computerName}"
}

function getDefaultUsername() {
  local username="`getDefaultFullname | tr '[:upper:]' '[:lower:]' | tr -C '[:alnum:]\n' '-'`"
  lop debug 'Default username based on current computer name is: '"$username"
  print "${username}"
}

function getUsersWithSecureToken() {
  local username
  for username in ${(f)"$(dscl . -list /Users | grep -v '^_.*')"}; do
    lop -n debug 'Checking if user '"${username}"' has a secure token set...'
    if checkSecureTokenForUser "${username}"; then
      lop debug 'found'
      secureTokenUsers+=("${username}")
    else
      lop debug 'not found'
    fi
  done
}

function getDefaultUserPictures() {
  pushd -q '/Library/User Pictures'
  defaultUserPictures=("${(@f)$(find -E . -type f -iregex '.*\.(tif|png|jpeg|jpg)' | abbreviatePaths)}")
  popd -q
}

function convertPathToDefaultPicture() {
  local resolved=''
  lop debug 'Converting path '"${filevault_picture}"' to default picture path if necessary.'
  if [ -r "${filevault_picture}" ]; then
    lop debug 'Path seems to be a valid path already. Skipping conversion.'
    return
  fi
  pushd -q '/Library/User Pictures'
  resolved="`find . -type f -path "*${filevault_picture}" 2> /dev/null`"
  lop debug 'Resolved path is' debug "${resolved}"
  popd -q
  [ -n "${resolved}" -a -r "${resolved}" ] && filevault_picture="${resolved}"
}

function isPathToPicture() {
  local filevault_picture=$1
  convertPathToDefaultPicture
  [ -r "${filevault_picture}" ] || { lop debug 'Resolved path is not a valid path. Returning.'; return 10 }
  [[ "${filevault_picture:e:l}" =~ (tif|png|jpeg|jpg) ]] || return 11
}

function checkSecureTokenForUser() {
  local u=$1
  sysadminctl -secureTokenStatus "${u}" 2>&1 | grep ENABLED >&! /dev/null
}

function checkSecureTokenUserPassword() {
  dscl . -authonly "${secure_token_user_username}" "${secure_token_user_password}" >&! /dev/null
}

function doesFileVaultUserExist() {
  dscl . -list /Users | grep "${filevault_username}" >&! /dev/null
}

function createFileVaultUser() {
  local un=${filevault_username} fn=${filevault_fullname} pw=${filevault_password}
  lop -n info 'Creating FileVault user' debug "${un}" info '...'
  sysadminctl -addUser "${un}" -fullName "${fn}" -shell /usr/bin/false -home '/var/empty' -password "${pw}" > /dev/null 2>&1
  lop success "done"
}

function configureFileVaultUser() {
  local un=${filevault_username}
  dscl . -create "/Users/${un}" IsHidden 1
  chsh -s /usr/bin/false "${un}"
  setPictureForUser "${un}" "${filevault_picture}"
}

function configureSecureToken() {
  local un=${filevault_username} up=${filevault_password}
  local stun=${secure_token_user_username} stup=${secure_token_user_password}
  sysadminctl -secureTokenOn "${un}" -password "${up}" -adminUser "${stun}" -adminPassword "${stup}" >&! /dev/null
}

function canUserUnlockDisk() {
  local username=$1
  for fdeuser in ${(f)"$(fdesetup list | cut -d',' -f1)"}; do
    [ "${fdeuser}" = "${username}" ] && return
  done
  return -1
}

function setPictureForUser() {
  local username="${1}"
  local image="${2}"
  dscl . delete "/Users/${username}" JPEGPhoto >&! /dev/null
  dscl . delete "/Users/${username}" Picture >&! /dev/null
  dsimport <(printf "0x0A 0x5C 0x3A 0x2C dsRecTypeStandard:Users 2 dsAttrTypeStandard:RecordName base64:dsAttrTypeStandard:JPEGPhoto\n%s:%s" "${username}" "$(base64 "${image}")") /Local/Default M
}

function allowOrEnableDiskUnlock() {
  local username="${1}" password="${2}" verb=enable
  if fdesetup isactive 2> /dev/null; then
    verb=add
    canUserUnlockDisk "${username}" && return
  fi
  echo "
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
" | fdesetup "${verb}" -inputplist 2> /dev/null
}

function allowOnlyFileVaultUserToUnlock() {
  local username="${1}"
  local fdeuser
  for fdeuser in ${(f)"$(fdesetup list | cut -d',' -f1)"}; do
    [ "${fdeuser}" != "${username}" ] && fdesetup remove -user "${fdeuser}"
  done
}

function configure_system() {
  checkSecureTokenForUser "${secure_token_user_username}" || { lop error 'The provided secure token user has no secure token.'; return 10 }
  checkSecureTokenUserPassword || { lop error 'The secure token user password is incorrect.'; return 11 }
  convertPathToDefaultPicture
  isPathToPicture "${filevault_picture}" || { lop error 'The provided FileVault user picture is not a valid path to a TIF, PNG or JPEG file.'; return 12 }

  doesFileVaultUserExist || createFileVaultUser
  configureFileVaultUser
  checkSecureTokenForUser "${filevault_username}" || configureSecureToken
  allowOrEnableDiskUnlock "${filevault_username}" "${filevault_password}"
  allowOnlyFileVaultUserToUnlock "${filevault_username}"
}

function checkPrerequisites() {
  local -A cmds=(
    [docopts]='(with -f option supported)'
    [tr]=''
    [cut]=''
    [dscl]=''
    [fdesetup]=''
    [base64]=''
    [dsimport]=''
    [sysadminctl]=''
    [scutil]=''
  )
  test "`id -u`" -eq 0 || { lop error 'This module requires root access. Please run as root.'; return 11 }
  checkCommands
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
    's: filevault-picture=Select a picture for FileVault user or enter the path to your own picture # validator:isPathToPicture;choose from:'"${(j.,.)defaultUserPictures};"
    's: secure-token-user-username=Which user with a secure token shall be used? # choose from:'"${(j.,.)secureTokenUsers};"
    'p: secure-token-user-password=What is the secure token user'\''s password?'
  )
}

function getUsage() {
  local cmdName=$1 text=''
  local defaultUsername="`getDefaultUsername`" defaultFullname="`getDefaultFullname`"
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions
	  $cmdName [-v] [-d FILE] --filevault-fullname NAME --filevault-username NAME --filevault-password PASSWORD --filevault-picture PATH_TO_PIC --secure-token-user-username NAME --secure-token-user-password PASSWORD
	
	Create a designated FileVault user who may not login to the system but is the
	only one able to unlock the disk. That way a secure password can be used to
	unlock the disk as opposed to macOS standard, where each user is allowed to
	unlock the disk with his password that may or may not be secure (in terms of
	length and randomness).
	
	Options:
	  --filevault-fullname NAME              Full name of the designated FileVault user. An
                                           existing FileVault user will be renamed to that
                                           name [default: ${defaultFullname}].
	  --filevault-username NAME              Username of the designated FileVault user. An
	                                         existing FileVault user will be renamed to that
	                                         name [default: ${defaultUsername}].
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
  print ${text}
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  test -f "${ASTZWEIG_MACOS_SYSTEM_LIB}" || { echo 'This module requires macos-system library. Please run again with macos-system library provieded as a path in ASTZWEIG_MACOS_SYSTEM_LIB env variable.'; return 10 }
  source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
  module_main $0 "$@"
fi
