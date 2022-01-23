#!/usr/bin/env zsh

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
  local tmddir="`mktemp -d -t 'macos-system'`"
  isDebug || trap "rm -fr -- '${tmpdir}'" EXIT
  pushd -q "${tmddir}"
  cloneMacOSSystemRepo
  cloneZSHLibRepo
  ./install.sh
  popd -q
}

main
