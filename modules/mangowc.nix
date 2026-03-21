{ types, ... }:
{
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.conf`.

        See the mangowc docs for valid options:
        https://mangowm.github.io/docs/configuration/basics

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.conf` file to be injected into the wrapped package.

        See the mangowc docs for valid options:
        https://mangowm.github.io/docs/configuration/basics

        Disjoint with the `settings` option.
      '';
    };
    autostartContents = {
      type = types.string;
      description = ''
        Script that get runs on startup, injected into the wrapped packages `autostart.sh`

        See the mangowc docs for valid options:
        https://mangowm.github.io/docs/configuration/basics#autostart

        Disjoint with the `autostartFile` option.
      '';
    };
    autostartFile = {
      type = types.pathLike;
      description = ''
        `autostart.sh` file to be injected into the wrapped package.

        See the mangowc docs for valid options:
        https://mangowm.github.io/docs/configuration/basics#autostart

        Disjoint with the `autostartContents` option.
      '';
    };
    package = {
      type = types.derivation;
      description = "The mangowc package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.mangowc;
    };
  };

  impl =
    { options, inputs }:
    assert !(options ? configFile && options ? settings);
    assert !(options ? autostartContents && options ? autostartFile);
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib.generators) toKeyValue;
      generator = attrs: writeText (toKeyValue {} attrs);
      configFlag =
        if options ? configFile then
          [
            "-c"
            "$out/mango/config.conf"
          ]
        else
          [];
      autostartFlag =
        if options ? autostartFile || options ? autostartContents then
          [
            "-s"
            "$out/mango/autostart.sh"
          ]
        else
          [];
    in
    inputs.mkWrapper {
      inherit (options) package;
      name = "mango";
      preSymlink = ''
        mkdir -p $out/mango
      '';
      symlinks = {
        "$out/mango/config.conf" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator options.settings
          else
            null;
        "$out/mango/autostart.sh" =
          if options ? autostartFile then
            options.autostartFile
          else if options ? autostartContents then
            writeText "autostart.sh" options.autostartContents
          else
            null;
      };
      flags = configFlag ++ autostartFlag;
    };
}
