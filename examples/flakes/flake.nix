{
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-unstable";
    };
    adios = {
      url = "github:llakala/lladios";
    };
    adios-wrappers = {
      url = "github:llakala/adios-wrappers";
      inputs.adios.follows = "adios";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      forAllSystems =
        function:
        lib.genAttrs [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ] (
          system: function system inputs.nixpkgs.legacyPackages.${system}
        );
    in {
      wrappers = forAllSystems (
        _: pkgs:
        import ./wrappers.nix {
          inherit pkgs;
          adios = inputs.adios.adios;
          adios-wrappers = inputs.adios-wrappers.wrapperModules;
        }
      );

      devShells = forAllSystems (
        system: pkgs:
        let
          wrappers = inputs.self.wrappers.${system};
        in {
          default = pkgs.mkShellNoCC {
            allowSubstitutes = false; # Prevent a cache.nixos.org call every time
            # TODO: add your wrappers here!
            packages = [
              wrappers.foo
              wrappers.bar
              wrappers.baz
            ];
          };
        }
      );
    };
}
