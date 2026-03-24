{ types, ... } @ adios:
{
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    flags = {
      type = types.listOf types.string;
      verify = adios.lib.disjointWith [ "configFile" ];
      description = ''
        Flags to be appended by default when running bat.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      verify = adios.lib.disjointWith [ "flags" ];
      description = ''
        File containing the flags to be appended by default when running bat.

        Disjoint with the `flags` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The bat package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.bat;
    };
  };

  impl =
    { options, inputs }:
    if options ? flags then
      inputs.mkWrapper {
        inherit (options) package flags;
      }
    else if options ? configFile then
      inputs.mkWrapper {
        inherit (options) package;
        environment = {
          BAT_CONFIG_PATH = options.configFile;
        };
      }
    else
      options.package;
}
