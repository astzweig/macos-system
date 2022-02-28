#!/usr/bin/env zsh
# vi: set expandtab ft=zsh tw=80 ts=2

function ensureDocopts() {
  which docopts > /dev/null
  [ $? -eq 0 ] && return
  curl --output ./docopts -fsSL https://github.com/astzweig/docopts/releases/download/v.0.7.0/docopts_darwin_amd64
  chmod u+x ./docopts
  PATH="${PATH}:`pwd`"
}

function cloneMacOSSystemRepo() {
  local repoUrl="${MACOS_SYSTEM_REPO_URL:-https://github.com/astzweig/macos-system.git}"
  git clone -q "${repoUrl}" .
}

function cloneZSHLibRepo() {
  local zshlibRepoUrl="${ZSHLIB_REPO_URL:-https://github.com/astzweig/zshlib.git}"
  git config --file=.gitmodules submodule.zshlib.url "${zshlibRepoUrl}"
  git submodule -q sync
  git submodule -q update --init --recursive --remote
}

function isDebug() {
  test "${DEBUG}" = true -o "${DEBUG}" = 1
}

function main() {
  local colors=()
  [ -t 2 ] && colors=(red "`tput setaf 1`" reset "`tput sgr0`")
  id -Gn | grep admin >&! /dev/null || { echo "${colors[red]}"'This script requires root access. Please run as an admin user.'"${colors[reset]}" >&2; return 10 }
  local tmpdir="`mktemp -d -t 'macos-system'`"
  isDebug || trap "rm -fr -- '${tmpdir}'; return" INT TERM EXIT
  pushd -q "${tmpdir}"
  printf 'Installing macos-system...'
  cloneMacOSSystemRepo
  printf 'done\n'
  printf 'Installing zshlib...'
  cloneZSHLibRepo
  printf 'done\n'
  printf 'Ensure docopts is installed...'
  ensureDocopts
  printf 'done\n'
  printf 'Will now run the installer\n.'
  sudo "${tmpdir}/install.sh" "$@"
  popd -q
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  _DIR="${0:A:h}"
  main "$@"
fi
