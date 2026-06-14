{ pkgs, adios, adios-wrappers }:
let
  inherit (pkgs) lib;

  root = {
    name = "root";
    modules = lib.recursiveUpdate adios-wrappers (adios.lib.importModules ./wrappers);
  };

  tree = adios root {
    options = {
      "/nixpkgs" = {
        inherit pkgs;
      };
    };
  };
in
# call each wrapper with empty args to get its output, since config was set
# through recursiveUpdate injections
builtins.mapAttrs (_: module: module {}) tree.modules
