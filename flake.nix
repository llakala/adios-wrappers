{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    adios.url = "github:llakala/adios/providers-and-consumers"; # My personal branch, adding callable impls and mutators
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs) lib;
      forAllSystems =
        function:
        lib.genAttrs [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ] (
          system: function inputs.nixpkgs.legacyPackages.${system}
        );
    in {
      wrapperModules = import ./default.nix {
        adios = inputs.adios;
      };
      devShells = forAllSystems (
        pkgs:
        let
          nixfmt = pkgs.callPackage ./dev/nixfmt.nix {};
        in {
          default = pkgs.mkShell {
            packages = [ nixfmt ];
          };
        }
      );
    };
}
