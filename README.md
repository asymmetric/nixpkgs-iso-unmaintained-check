# nixpkgs-iso-unmaintained-check

Checks which packages are unmaintained in the NixOS minimal ISO.

## Usage

```
./check.sh -h
```

This script relies on the value of `<nixpkgs>`, so you can use the `NIX_PATH` variable to set it to a value of your choosing:

```
NIX_PATH=nixpkgs=/foo/bar/baz ./check.sh
```

## How it works

- Gets list of **store paths** in the build and runtime closures for the minimal ISO
- Tries to match those against the list of unmaintained **packages** in Nixpkgs

Note that, because Nix has no notion of packages, we have to apply some **fuzzy matching** here.

Given something like `/nix/store/asdf-foo-123.drv`, the program:
- removes `/nix/store/asdf-`
- removes `.drv`
- removes `-123`

To end up with `foo`, which is hopefully also the package name, as returned by `nix-env -qa`.

Given this limitation, the list should only be interpreted as a first approximation, and a lower bound on the number of unmaintained packages.
