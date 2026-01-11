# NOTE

This is a new project, which only has a small set of modules at the moment. Users are expected to have some Adios knowledge coming in.

# Vendoring

## Flakes

First, add the repo to your flake inputs:

```nix
inputs = {
  adios = {
    # Make sure to use this branch!
    url = "github:llakala/adios/providers-and-consumers";
  };
  adios-wrappers = {
    url = "github:llakala/adios-wrappers";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.adios.follows = "adios";
  };
};
```

Now, create a flake output to expose your wrappers:

```nix
outputs = inputs: {
  # If you don't already have forAllSystems set up, see this guide:
  # https://ayats.org/blog/no-flake-utils#do-we-really-need-flake-utils
  wrappers = forAllSystems (pkgs:
    import ./wrappers/default.nix {
      inherit pkgs;
      adios = inputs.adios.adios;
      adios-wrappers = inputs.adios-wrappers.wrapperModules;
    }
  );
};
```

You'll notice we referenced a file under `wrappers/default.nix`. This file should contain these contents:
```nix
{
  pkgs,
  adios,
  adios-wrappers,
}:
let
  inherit (pkgs) lib;

  # Allow overriding the vendored wrappers with your own config.
  #
  # For example, to inject your own config into the git wrapper, you would
  # create a `git/settings.nix` file with these contents:
  #
  # { adios }:
  # {
  #   options.settings.default = import ./settings.nix;
  # }
  root = {
    name = "root";
    modules = lib.recursiveUpdate adios-wrappers (adios.lib.importModules ./.);
  };

  tree = (adios root).eval {
    options = {
      "/nixpkgs" = {
        inherit pkgs;
      };
    };
  };
in
tree.root.modules
```

## Non-flakes

I'll go over npins-specific instructions here. Any other source pinning tool should work the same.

First, add the relevant sources to your lockfile:

```
npins init # Only if you don't already have an `npins/` folder
npins add github llakala adios -b providers-and-consumers
npins add github llakala adios-wrappers -b main
```

Now, create a file under `wrappers/default.nix`, containing these contents:

```nix
{
  sources ? import ../npins,
}:
let
  pkgs = import sources.nixpkgs { };
  inherit (pkgs) lib;
  adios = import "${sources.adios}/adios";
  adios-wrappers = import sources.adios-wrappers { adiosPath = sources.adios.outPath; };

  # Allow overriding the vendored wrappers with your own config.
  #
  # For example, to inject your own config into the git wrapper, you would
  # create a `git/settings.nix` file with these contents:
  #
  # { adios }:
  # {
  #   options.settings.default = import ./settings.nix;
  # }
  root = {
    name = "root";
    modules = lib.recursiveUpdate adios-wrappers (adios.lib.importModules ./.);
  };

  tree = (adios root).eval {
    options = {
      "/nixpkgs" = {
        inherit pkgs;
      };
    };
  };
in
tree.root.modules
```

# Usage

TODO
