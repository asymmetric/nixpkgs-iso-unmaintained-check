{ pkg }:
let
  pkgs = import <nixpkgs> { };
  has_tests = pkgs.${pkg}.passthru ? tests;
  has_update_script = pkgs.${pkg}.passthru ? updateScript;
in
{
  has_tests = has_tests;
  has_update_script = has_update_script;
}
