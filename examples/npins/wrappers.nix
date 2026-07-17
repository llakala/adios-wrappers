{
  sources ? import ../npins,
  pkgs ? import sources.nixpkgs {},
}:
let
  adios = import "${sources.adios}/adios";
  adios-wrappers = import sources.adios-wrappers { inherit adios; };

  root = {
    modules = adios.lib.inject [
      adios-wrappers
      # wrappers dir doesn't exist yet - add that yourself with your own
      # injections (see the usage docs)
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
# call each wrapper with empty args to get its output
builtins.mapAttrs (_: module: module {}) tree.modules
