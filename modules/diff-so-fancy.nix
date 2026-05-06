_: {
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
    git.path = "/git";
  };

  inputs.mkWrapper.overrides = {
    package.computedValue = { inputs }: inputs.nixpkgs.pkgs.diff-so-fancy;
    environment.computedValue =
      { inputs }:
      let
        gitWrapper = inputs.git {};
      in {
        # If you don't have this, diff-so-fancy can't find your gitconfig
        GIT_CONFIG_GLOBAL = "${gitWrapper}/git/config";
      };
  };

  impl = { options, inputs }: inputs.mkWrapper {};

  meta = {
    maintainers = [ "llakala" ];
  };
}
