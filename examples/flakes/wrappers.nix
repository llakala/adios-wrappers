{ pkgs, adios, adios-wrappers }:
let
  root = {
    modules = adios.lib.inject [
      adios-wrappers
      (adios.lib.importModules { directory = ./wrappers; })
    ];
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
# through injections
builtins.mapAttrs (_: module: module {}) tree.modules
