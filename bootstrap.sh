#!/usr/bin/env zsh
# vi: set expandtab ft=zsh tw=80 ts=2

function ensureDocopts() {
  which docopts > /dev/null && return
  local fileURL="${DOCOPTS_URL:-https://github.com/astzweig/docopts/releases/download/v.0.7.0/docopts_darwin_amd64}"
  curl --output ./docopts -fsSL "${fileURL}" || return
  chmod u+x ./docopts
  PATH="${PATH}:`pwd`"
}

function cloneMacOSSystemRepo() {
  local repoUrl="${MACOS_SYSTEM_REPO_URL:-https://github.com/astzweig/macos-system.git}"
  git clone -q "${repoUrl}" . 2> /dev/null || return 10
  [ -n "${MACOS_SYSTEM_REPO_BRANCH}" ] && git checkout ${MACOS_SYSTEM_REPO_BRANCH} 2> /dev/null || true
}

function cloneZSHLibRepo() {
  local zshlibRepoUrl="${ZSHLIB_REPO_URL:-https://github.com/astzweig/zshlib.git}"
  git config --file=.gitmodules submodule.zshlib.url "${zshlibRepoUrl}"
  git submodule -q sync
  [ -n "${ZSHLIB_REPO_BRANCH}" ] && git submodule set-branch -b ${ZSHLIB_REPO_BRANCH} `git config --file=.gitmodules submodule.zshlib.path` 2> /dev/null || true
  git submodule -q update --init --recursive --remote 2> /dev/null || return 10
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
  [ -t 1 ] && colors=("${(kv)colorCodes[@]}")
  [ -t 2 ] && errColors=("${(kv)colorCodes[@]}")
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

function main() {
  local -A colors=() errColors=()
  defineColors
  id -Gn | grep admin >&! /dev/null || { printError 'This script requires root access. Please run as an admin user.'; return 10 }
  local tmpdir="`mktemp -d -t 'macos-system'`"
  isDebug || trap "rm -fr -- '${tmpdir}'; return" INT TERM EXIT
  pushd -q "${tmpdir}"
  print -l "Working directory is: ${tmpdir}"

  ensureRepo 'macos-system' cloneMacOSSystemRepo || return
  ensureRepo 'zshlib' cloneZSHLibRepo || return
  ensureBinary 'docopts' ensureDocopts || return

  print 'Will now run the installer.'
  sudo "${tmpdir}/install.sh" "$@"
  popd -q
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  _DIR="${0:A:h}"
  main "$@"
fi
