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

- Gets list of **store paths** in build and runtime closure for the minimal ISO
- Tries to match those against the list of unmaintained **packages** in Nixpkgs

Note that because Nix has no notion of packages, we have to apply some fuzzy matching here.

Therefore, the list is only a lower bound.
