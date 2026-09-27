{ types, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.conf`.

        See the mangowc [docs](https://mangowm.github.io/docs/configuration/basics) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.conf` file to be injected into the wrapped package.

        See the mangowc [docs](https://mangowm.github.io/docs/configuration/basics) for valid options.

        Disjoint with the `settings` option.
      '';
    };

    autostartContents = {
      type = types.string;
      description = ''
        Script that get runs on startup, injected into the wrapped packages `autostart.sh`

        See the mangowc [docs](https://mangowm.github.io/docs/configuration/basics#autostart) for valid options.

        Disjoint with the `autostartFile` option.
      '';
    };
    autostartFile = {
      type = types.pathLike;
      description = ''
        `autostart.sh` file to be injected into the wrapped package.

        See the mangowc [docs](https://mangowm.github.io/docs/configuration/basics#autostart) for valid options.

        Disjoint with the `autostartContents` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.mango;
      description = "The mangowc package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "configFile" "settings")
    (assertions.disjoint "autostartContents" "autostartFile")
  ];

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText formats;
      generator = formats.keyValue {};
      configFlag =
        if options ? configFile || options ? settings then
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
      symlinks = {
        "$out/mango/config.conf" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.conf" options.settings
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

  meta = {
    maintainers = [ "Squawkykaka" ];
  };
}
