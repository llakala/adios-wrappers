{ types, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
    git.from = { parent }: parent.git;
  };

  options = {
    package = {
      type = types.derivation;
      description = "The diff-so-fancy package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.diff-so-fancy;
    };
  };

  impl =
    { options, inputs }:
    let
      gitWrapper = inputs.git {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      environment = {
        # If you don't have this, diff-so-fancy can't find your gitconfig
        GIT_CONFIG_GLOBAL = "${gitWrapper}/git/config";
      };
    };

  meta = {
    maintainers = [ "llakala" ];
  };
}
