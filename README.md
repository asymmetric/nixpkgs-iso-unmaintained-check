# nixpkgs-iso-unmaintained-check

Checks which packages are unmaintained in the NixOS minimal ISO.

## Usage

```
./iso-unmaintained.sh -h
```

## How it works

- Gets list of **store paths** in build and runtime closure for the minimal ISO
- Tries to match those against the list of unmaintained **packages** in Nixpkgs

Note that because Nix has no notion of packages, we have to apply some fuzzy matching here.

Therefore, the list is only a lower bound.
