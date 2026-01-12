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
  root = {
    name = "root";
    modules = # TODO
  };

  wrapperModules = (adios root).eval {
    options = {
      "/nixpkgs" = {
        inherit pkgs;
      };
    };
  };
in
# TODO: decide what to put here in the `usage` section
```

Finally, add a devshell (if you don't have one already) to your flake outputs, to allow iterating on your wrappers
without a full system rebuild:

```nix
outputs = inputs: {
  devShells = forAllSystems (
    pkgs:
    let
      wrappers = inputs.self.wrappers.${pkgs.stdenv.hostPlatform.system};
    in {
      default = pkgs.mkShellNoCC {
        allowSubstitutes = false; # Prevent a cache.nixos.org call every time
        packages = [
          wrappers.foo
          wrappers.bar
          wrappers.baz
        ];
      };
    }
  ;
};
```

Now that you've installed adios-wrappers, feel fre to move onto the [usage instructions](./usage.md).
