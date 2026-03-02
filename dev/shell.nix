{
  sources ? import ./npins,
  pkgs ? import sources.nixpkgs {}
}:
let
  nixfmt = pkgs.callPackage ./nixfmt.nix {};
in {
  default = pkgs.mkShell {
    packages = [
      nixfmt
      pkgs.npins
      pkgs.jq
      pkgs.pre-commit
    ];

    shellHook = ''
      pre-commit install
    '';
  };
}
