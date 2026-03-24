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
        Flags to be automatically appended when running ripgrep.

        See the documentation of valid flags:
        https://manpages.ubuntu.com/manpages/jammy/man1/rg.1.html#:~:text=OPTIONS

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      verify = adios.lib.disjointWith [ "flags" ];
      description = ''
        `ripgreprc` file, containing flags to be automatically appended when running ripgrep.

        See the documentation of valid flags:
        https://manpages.ubuntu.com/manpages/jammy/man1/rg.1.html#:~:text=OPTIONS

        This file should have each flag on its own line. See the documentation of the file's format:
        https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file

        Disjoint with the `configFile` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The ripgrep package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.ripgrep;
    };
  };

  impl =
    { options, inputs }:
    if options ? flags then
      inputs.mkWrapper {
        name = "rg";
        inherit (options) package flags;
      }
    else
      inputs.mkWrapper {
        name = "rg";
        environment = {
          RIPGREP_CONFIG_PATH = options.configFile or null;
        };
      };
}
