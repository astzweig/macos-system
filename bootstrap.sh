#!/usr/bin/env zsh

function main() {
  local tmddir="`mktemp -d -t 'macos-system'`"
  trap 'rm -fr -- "${tmpdir}"' EXIT
  pushd -q "${tmddir}"
  git clone --recurse-submodules https://github.com/astzweig/macos-system.git .
  ./install.sh
  popd -q
}

main
