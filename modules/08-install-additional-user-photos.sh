#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function convertRelativePathToResourcesDir() {
	local resolved=''
	lop -- -d 'Converting path' -d "${picture_folder}" -d 'to a resources path if necessary.'
	if [ -d "${picture_folder}" ]; then
		lop -- -d 'Path seems to be a valid path already. Skipping conversion.'
		return
	fi
	pushd -q ${_DIR}/../'resources'
	resolved=$_/${picture_folder}
	lop -- -d 'Resolved path is' -d "${resolved}"
	popd -q
	[ -n "${resolved}" -a -d "${resolved}" ] && picture_folder="${resolved}"
}

function findAvailableDestinationFolder() {
	local folderName=${picture_folder_name} counter=2
	while [[ -d '/Library/User Pictures/'$folderName ]]; do
		folderName="$folderName $counter"
		counter=$((counter + 1))
	done
	destinationFolder='/Library/User Pictures/'$folderName
}

function copyPictureFolderToDestination() {
	cp -r $picture_folder $destinationFolder
}

function fixPermissions() {
	chown -R root:wheel $destinationFolder
	chmod ugo+rx $destinationFolder
	find $destinationFolder -type d -exec chmod ugo+rx {} \;
	find $destinationFolder -type f -exec chmod ugo+r {} \;
}

function configure_system() {
	local destinationFolder=
	lop -y h1 -- -i 'Install Additional User Pictures'
	indicateActivity -- 'Resolve path if relative to resources directory' convertRelativePathToResourcesDir
	[[ ! -d ${picture_folder} ]] && { lop -- -e 'Provided picture folder does not exist. Aborting.'; return 10 }
	[[ -n ${picture_folder_name} ]] || { lop -- -e 'Provided an empty picture folder name. Aborting.'; return 11 }
	indicateActivity -- 'Find available destination folder' findAvailableDestinationFolder
	indicateActivity -- 'Copy pictures to destination folder' copyPictureFolderToDestination
	indicateActivity -- 'Set correct permissions' fixPermissions
}

function getExecPrerequisites() {
	cmds=(
		[git]=''
	)
	re
}

function getDefaultUserPictureFolderPath() {
	pushd -q ${_DIR}/..
	print -- ${USER_PICTURE_FOLDER_PATH:-user-pictures}
	popd -q
}

function getDefaultPictureFolderName() {
	print Astzweig
}

function getQuestions() {
	questions=(
		'i: picture-folder=Which folder includes the user pictures to install? # default:'"$(getDefaultUserPictureFolderPath)"
		'i: picture-folder-name=How shall the picture folder be named once copied to the system files? # default:'"$(getDefaultPictureFolderName)"
	)
}

function getUsage() {
	read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE] --picture-folder PATH --picture-folder-name NAME

	Install additional user pictures.

	Options:
	  --picture-folder PATH       Path to the folder containing the user pictures
	                              [default: $(getDefaultUserPictureFolderPath)].
	  --picture-folder-name NAME  Name of the picture folder once copied to the system
	                              files [default: $(getDefaultPictureFolderName)].
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
	_DIR="${0:A:h}"
	test -f "${ASTZWEIG_MACOS_SYSTEM_LIB}" || { echo 'This module requires macos-system library. Please run again with macos-system library provieded as a path in ASTZWEIG_MACOS_SYSTEM_LIB env variable.'; return 10 }
	source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
	module_main $0 "$@"
fi
