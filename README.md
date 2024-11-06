# nixpkgs-iso-unmaintained-check

Checks which packages are unmaintained in the NixOS minimal ISO package for the host's `system`.

## Usage

```
./check.sh -h
```

This script relies on the value of `<nixpkgs>`, so you can use the `NIX_PATH` variable to set it to a value of your choosing:

```
NIX_PATH=nixpkgs=/foo/bar/baz ./check.sh
```

If the `--debug` flag is set, the script will keep around the temporary directory where it saves intermediate files, for closer inspection.

The script prints out what it's doing to stderr, whereas stdout is used only for the final output, which you can therefore easily pipe/redirect, as it won't contain any other information.

## How it works

- Gets list of **store paths** in the build and runtime closures for the minimal ISO
- Tries to match those against the list of unmaintained **packages** in Nixpkgs

Note that, because Nix has no notion of packages, we have to be "creative" in matching store paths to packages.

Given something like `/nix/store/asdf-foo-123.drv`, the program:
- removes `/nix/store/asdf-`
- removes `.drv`
- removes `-123`

To end up with `foo`, which is hopefully also the package name, as returned by `nix-env -qa`.

Given this and other limitations, the list should only be interpreted as a first approximation.

## TODO

- remove hooks
- remove wrappers
