{ types, ... }:
{
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
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
  };

  inputs.mkWrapper.overrides = {
    package.computedValue = { inputs }: inputs.nixpkgs.pkgs.bat;
  };

  impl =
    { options, inputs }:
    assert !(options ? flags && options ? configFile);
    if options ? flags then
      inputs.mkWrapper {
        inherit (options) flags;
      }
    else if options ? configFile then
      inputs.mkWrapper {
        environment = {
          BAT_CONFIG_PATH = options.configFile;
        };
      }
    else
      options.package;

  meta = {
    maintainers = [ "llakala" ];
  };
}
