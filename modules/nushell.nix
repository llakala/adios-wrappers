{ types, ... } @ adios:
{
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    shellInit = {
      type = types.string;
      description = ''
        Shell initialisation code to be injected into the wrapped package's `config.nu`.

        See the nushell documentation for valid options:
        https://www.nushell.sh/book/configuration.html

        Disjoint with the `configFile` option.
      '';
      mutatorType = types.string;
      mergeFunc = adios.lib.merge.strings.concatLines;
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.nu` file to be injected into the wrapped package.

        See the nushell documentation on file syntax:
        https://www.nushell.sh/book/configuration.html

        Disjoint with the `config` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The nushell package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.nushell;
    };
  };

  impl =
    { options, inputs }:
    assert !(options ? shellInit && options ? configFile);
    let
      inherit (inputs.nixpkgs.pkgs) writeText;

      configNu =
        if options ? configFile then
          options.configFile
        else if options ? shellInit then
          writeText "config.nu" options.shellInit
        else
          null;
    in
    inputs.mkWrapper {
      name = "nu";
      inherit (options) package;
      preSymlink = ''
        mkdir -p $out/nushell
      '';
      symlinks = {
        "$out/nushell/config.nu" = configNu;
      };
      flags = (
        if (configNu != null) then
          [
            "--config"
            "$out/nushell/config.nu"
          ]
        else
          []
      );
    };
}
