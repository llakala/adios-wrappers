{ types, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be appended by default when running bat.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        File containing the flags to be appended by default when running bat.

        Disjoint with the `flags` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.bat;
      description = "The bat package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    assert options ? flags != options ? configFile;
    inputs.mkWrapper (
      if options ? flags then
        {
          inherit (options) package flags;
        }
      else
        {
          inherit (options) package;
          environment = {
            BAT_CONFIG_PATH = options.configFile;
          };
        }
    );

  meta = {
    maintainers = [ "llakala" ];
  };
}
