#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function versionGT() {
	[[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -gt "${2#*.}" ]]
}

function majorMinor() {
	echo "${1%%.*}.$(x="${1#*.}" echo "${x%%.*}")"
}

function shouldInstallCommandLineTools() {
	local macosVersion=$(majorMinor $(/usr/bin/sw_vers -productVersion))
	if versionGT "${macosVersion}" "10.13"
	then
		! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]]
	else
		! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]] ||
			! [[ -e "/usr/include/iconv.h" ]]
	fi
}

function removeNewlines() {
	printf "%s" "${1/"$'\n'"/}"
}

function acceptXcodeLicense() {
	xcodebuild -license accept
}

function installCommandLineTools() {
	shouldInstallCommandLineTools || return
	cltPlaceholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
	touch ${cltPlaceholder}

	cltLabelCommand="/usr/sbin/softwareupdate -l |
										grep -B 1 -E 'Command Line Tools' |
										awk -F'*' '/^ *\\*/ {print \$2}' |
										sed -e 's/^ *Label: //' -e 's/^ *//' |
										sort -V |
										tail -n1"
	cltLabel="$(removeNewlines "$(/bin/bash -c "${cltLabelCommand}")")"

	if [[ -n "${cltLabel}" ]]
	then
		/usr/sbin/softwareupdate -i ${cltLabel}
		/usr/bin/xcode-select --switch /Library/Developer/CommandLineTools
	fi
	rm -f ${cltPlaceholder}
}

function ensureCommandLineTools() {
	installCommandLineTools
	acceptXcodeLicense
}

function ensureDocopts() {
	which docopts > /dev/null && return
	local fileURL="${DOCOPTS_URL:-https://github.com/astzweig/docopts/releases/download/v.0.7.0/docopts_darwin_amd64}"
	curl --output ./docopts -fsSL "${fileURL}" || return
	chmod u+x ./docopts
	PATH="${PATH}:`pwd`"
}

function cloneMacOSSystemRepo() {
	local repoUrl="${MACOS_SYSTEM_REPO_URL:-https://github.com/astzweig/macos-system.git}"
	git clone --depth 1 -q "${repoUrl}" . 2> /dev/null || return 10
	[ -n "${MACOS_SYSTEM_REPO_BRANCH}" ] && git checkout -q ${MACOS_SYSTEM_REPO_BRANCH} 2> /dev/null || true
}

function cloneZSHLibRepo() {
	local zshlibRepoUrl="${ZSHLIB_REPO_URL:-https://github.com/astzweig/zshlib.git}"
	git config --file=.gitmodules submodule.zshlib.url "${zshlibRepoUrl}"
	git submodule -q sync
	[ -n "${ZSHLIB_REPO_BRANCH}" ] && git submodule set-branch -b ${ZSHLIB_REPO_BRANCH} `git config --file=.gitmodules submodule.zshlib.path` 2> /dev/null || true
	git submodule -q update --depth 1 --init --recursive --remote 2> /dev/null || return 10
}

function isDebug() {
	test "${DEBUG}" = true -o "${DEBUG}" = 1
}

function printSuccess() {
	print "${colors[green]}${*}${colors[reset]}"
}

function printError() {
	print "${errColors[red]}${*}${errColors[reset]}" >&2
}

function printFailedWithError() {
	print "${colors[red]}failed.${colors[reset]}"
	print "$*" >&2
}

function defineColors() {
	local -A colorCodes=(red "`tput setaf 9`" green "`tput setaf 10`" reset "`tput sgr0`")
	[ -t 1 ] && colors=( ${(kv)colorCodes} )
	[ -t 2 ] && errColors=( ${(kv)colorCodes} )
}

function ensureRepo() {
	local repoName="$1" cmdName="${2}"
	print -n "Installing ${1}..."
	$cmdName || { printFailedWithError "This script requires $repoName but was not able to clone it. Please ensure access to the $repoName repository."; return 10}
	printSuccess 'done'
}

function ensureBinary() {
	local binaryName="$1" cmdName="${2}"
	print -n "Ensure ${1} is installed..."
	$cmdName || { printFailedWithError "This script requires $binaryName but was neither able to locate and install it. Please install $binaryName and add it to one of the PATH directories."; return 10}
	printSuccess 'done'
}

function configureTerminal() {
	if [ -t 0 ]; then
		traps+=("stty $(stty -g)")
		stty -echo
	fi

	if [ -t 1 ]; then
		traps+=('tput cnorm')
		tput civis
		export TERMINAL_CURSOR_HIDDEN=true
	fi
}

function main() {
	local traps=()
	local -A colors=() errColors=()
	defineColors

	configureTerminal
	local tmpdir="`mktemp -d -t 'macos-system'`"
	isDebug || traps+=("rm -fr -- '${tmpdir}'")
	trap ${(j.;.)traps} INT TERM EXIT
	pushd -q "${tmpdir}"
	print -l "Working directory is: ${tmpdir}"

	print 'Ensure command line tools are available.'
	ensureCommandLineTools
	ensureRepo 'macos-system' cloneMacOSSystemRepo || return
	ensureRepo 'zshlib' cloneZSHLibRepo || return
	ensureBinary 'docopts' ensureDocopts || return

	print 'Will now run the installer.'
	[ -t 1 ] && tput cnorm
	isDebug && export MACOS_SYSTEM_DEBUG=true
	"${tmpdir}/install.sh" "$@"
	[ -t 1 ] && tput civis
	popd -q
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel || "${ZSH_EVAL_CONTEXT}" == cmdarg ]]; then
	_DIR="${0:A:h}"
	main "$@"
fi
