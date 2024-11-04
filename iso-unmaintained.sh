#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -dt tmp.XXXXXXXXXX)
DEBUG=0
BUILD_DEPS=1
RUNTIME_DEPS=1

usage() {
  echo "Usage: $0 [--debug|-d] [--help|-h] [--no-build] [--no-runtime]"
}
while [[ $# -gt 0 ]]; do
  case $1 in
    --debug|-d)
      DEBUG=1
      echo saving to $TMPDIR
      echo nix_path is $NIX_PATH
      shift;;
    --help|-h)
      usage
      exit 0
      ;;
    --no-build)
      BUILD_DEPS=0
      shift
      ;;
    --no-runtime)
      RUNTIME_DEPS=0
      shift
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if [[ $BUILD_DEPS -eq 0 && RUNTIME_DEPS -eq 0 ]]; then
  echo "Can't disable both build-time and run-time dependencies"
  exit 1
fi

cleanup() {
  if [[ $DEBUG -eq 0 ]]; then
    rm -rf $TMPDIR
  fi
}

# Try to extract program name from store path.
# Given something like /nix/store/asdf-foo-123.drv
# - removes /nix/store/asdf-
# - removes .drv
# - removes -123
process() {
  while IFS= read -r line; do
    processed_line=$(echo $line | cut -d- -f2- | cut -d. -f1 | sed -E 's/-[0-9]+$//')
    echo $processed_line
  done
}

trap "cleanup; exit 1" SIGINT

iso_drv=$(nix-instantiate --quiet '<nixpkgs/nixos>' -A config.system.build.isoImage --arg configuration "{ imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> ]; }")

declare build_deps runtime_deps

if [[ $BUILD_DEPS -eq 1 ]]; then
  build_deps=$(nix-store -qR $iso_drv | process | sort -u | tee $TMPDIR/bld)
fi
if [[ $RUNTIME_DEPS -eq 1 ]]; then
  # need to call --quiet 3 times to stop nix-store from complaining about missing --add-root, smh
  runtime_deps=$(nix-store -qR $(nix-store -r --quiet --quiet --quiet --no-build-output $iso_drv) | process | sort -u | tee $TMPDIR/run )
fi


# Convert store paths to package names (f1)
cat <(echo "$build_deps") <(echo "$runtime_deps") | sort -u | tee $TMPDIR/combined  > $TMPDIR/f1

# Find all unmaintained packages in nixpkgs (f2)
nix-env -qa --no-name --json --meta --file '<nixpkgs>' 2>/dev/null | jq -r 'map_values(select(.meta.maintainers == null or .meta.maintainers == [])) | .[].pname' | sort -u > $TMPDIR/f2

# Print the intersection of f1 and f2, i.e. all unmaintained packages in the iso image's closure
comm -12 $TMPDIR/f{1,2}

cleanup
