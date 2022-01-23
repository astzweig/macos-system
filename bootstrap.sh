#!/usr/bin/env zsh
# vi: set expandtab ft=zsh tw=80 ts=2

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
  test "${DEBUG}" -eq 1 -o "${DEBUG}" = true
}

function main() {
  local tmpdir="`mktemp -d -t 'macos-system'`"
  isDebug || trap "rm -fr -- '${tmpdir}'; return" INT TERM EXIT
  pushd -q "${tmpdir}"
  cloneMacOSSystemRepo
  cloneZSHLibRepo
  ./install.sh
  popd -q
}

main
