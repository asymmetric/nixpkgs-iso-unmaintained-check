#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils jq
# shellcheck shell=bash

set -euo pipefail

TMPDIR=$(mktemp -dt tmp.XXXXXXXXXX)
DEBUG=0
BUILD_DEPS=1
RUNTIME_DEPS=1

# tell Nix to stop printing warnings
QUIET=(--quiet --quiet --quiet)

usage() {
  echo "Usage: $0 [--debug|-d] [--help|-h] [--no-buildtime] [--no-runtime]"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --debug|-d)
      DEBUG=1
      echo saving to "$TMPDIR" >&2
      echo nix_path is "$NIX_PATH" >&2
      shift;;
    --help|-h)
      usage
      exit 0
      ;;
    --no-buildtime)
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

if [[ $BUILD_DEPS -eq 0 && $RUNTIME_DEPS -eq 0 ]]; then
  echo "Can't disable both build-time and run-time dependencies"
  exit 1
fi

cleanup() {
  if [[ $DEBUG -eq 0 ]]; then
    rm -rf "$TMPDIR"
  fi
}

# Extracts attribute path from store path.
#
# Given something like
#   /nix/store/yhjs7r0mzh2wlli8r6b8wyc85wyrhipq-python3.12-babel-2.15.0.drv
# it returns
#   python3.12-babel-2.15.0
# Note that we want to preserve the python3.12 part, because it's part of the name/pname of a derivation.
process() {
  # The `IFS=` ensures word spitting doesn't happen on any character, i.e. that
  # we read a whole line.
  while IFS= read -r line; do
    # strip .drv, which is only present for build-time deps.
    processed_line=${line%.drv}

    # Remove until end of hash, i.e. first -, included.
    processed_line=${processed_line#*-}

    echo "$processed_line"
  done
}

trap "cleanup; exit 1" SIGINT

echo "Instantiating store derivation..." >&2
drv=$(nix-instantiate "${QUIET[@]}" '<nixpkgs/nixos>' -A config.system.build.isoImage --arg configuration "{ imports = [ <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix> ]; }")

build_deps=""
runtime_deps=""

if [[ $BUILD_DEPS -eq 1 ]]; then
  echo "Getting build-time closure..." >&2
  build_deps=$(nix-store -qR "$drv" | tee "$TMPDIR"/bld-pre | process | sort -u | tee "$TMPDIR"/bld-post)
fi
if [[ $RUNTIME_DEPS -eq 1 ]]; then
  echo "Getting run-time closure..." >&2
  runtime_deps=$(nix-store -qR "$(nix-store -r "${QUIET[@]}" --no-build-output "$drv")" | tee "$TMPDIR"/run-pre | process | sort -u | tee "$TMPDIR"/run-post)
fi


# Convert store paths to package names (f1)
cat <(echo "$build_deps") <(echo "$runtime_deps") | sort -u | tee "$TMPDIR"/deps  > "$TMPDIR"/f1

# Find all unmaintained packages in nixpkgs (f2)
echo "Getting list of unmaintained packages..." >&2
nix-env -qa --json --meta --file '<nixpkgs>' 2>/dev/null | jq -r 'map_values(select(.meta.maintainers == null or .meta.maintainers == [])) | .[].name' | sort -u > "$TMPDIR"/f2

# Print the intersection of f1 and f2, i.e. all unmaintained packages in the iso image's closure
comm -12 "$TMPDIR"/f{1,2} | tee "$TMPDIR"/pkgs | while read -r pkg; do
  json=$(nix-instantiate --eval --strict ./passthru.nix --argstr pkg "$pkg" --json)

  if [[ $(echo "$json" | jq .has_tests) == "true" ]]; then
    echo "had tests"
  fi
  if [[ $(echo "$json" | jq .has_update_script) == "true" ]]; then
    echo "had update script"
  fi
done


cleanup
