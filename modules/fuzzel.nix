{ types, promise, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `fuzzel.ini`.

        See the [documentation](https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.ini.5.scd) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `fuzzel.ini` file to be injected into the wrapped package.

        See the [documentation](https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.ini.5.scd) for syntax and valid options.

        Disjoint with the `settings` option.
      '';
    };

    dmenuFlags = {
      type =
        (types.struct "dmenuFlags" {
          dmenu = types.bool;
          dmenu0 = types.bool;
          withNth = types.string;
          acceptNth = types.string;
          delimitNth = types.string;
          noEmpty = types.bool;
          index = types.bool;
        }).override
          { total = false; };
      description = ''
        Dmenu related flags to pass to fuzzel when using `settings`/`configFile`

        See the [documentation](https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.1.scd) for valid syntax and formatting of the related flags.

        Requires that either `settings`/`configFile` be set.
      '';
    };

    logFlags = {
      type =
        (types.struct "logFlags" {
          logLevel = types.string;
          colorize = types.string;
          noSyslog = types.bool;
          printTiming = types.bool;
        }).override
          { total = false; };
      description = ''
        Logging related flags to pass to fuzzel when using `settings`/`configFile`

        See the [documentation](https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.1.scd) for valid syntax and formatting of the related flags.

        Requires that either `settings`/`configFile` be set.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.fuzzel);
      description = "The fuzzel package to be wrapped.";
    };
  };

  # TODO: add 'assertions.oneOf' (name pending) for this usecase
  assertions = [
    {
      verify = { options }: options ? settings != options ? configFile;
      explain =
        { options }:
        if options ? settings then
          "both 'options.settings' or 'options.configFile' were set"
        else
          "neither 'options.settings' nor 'options.configFile' were set";
    }
  ];

  inputs.mkWrapper.options = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) optionals;
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.ini {};
      dmenuFlags =
        if options ? dmenuFlags then
          optionals (options.dmenuFlags ? dmenu && options.dmenuFlags.dmenu) [ "--dmenu" ]
          ++ optionals (options.dmenuFlags ? dmenu0 && options.dmenuFlags.dmenu0) [ "--dmenu0" ]
          ++ optionals (options.dmenuFlags ? withNth) [ "--with-nth=${options.dmenuFlags.withNth}" ]
          ++ optionals (options.dmenuFlags ? acceptNth) [ "--accept-nth=${options.dmenuFlags.acceptNth}" ]
          ++ optionals (options.dmenuFlags ? delimitNth) [
            "--nth-delimiter=${options.dmenuFlags.delimitNth}"
          ]
          ++ optionals (options.dmenuFlags ? noEmpty && options.dmenuFlags.noEmpty) [ "--no-run-if-empty" ]
          ++ optionals (options.dmenuFlags ? index && options.dmenuFlags.index) [ "--index" ]
        else
          [];
      logsFlags =
        if options ? logFlags then
          optionals (options.logFlags ? logLevel) [ "--log-level=${options.logFlags.logLevel}" ]
          ++ optionals (options.logFlags ? colorize) [ "--log-colorize=${options.logFlags.colorize}" ]
          ++ optionals (options.logFlags ? noSyslog && options.logFlags.noSyslog) [ "--log-no-syslog" ]
          ++ optionals (options.logFlags ? printTiming && options.logFlags.printTiming) [
            "--print-timing-info"
          ]
        else
          [];
      configFlag =
        if options ? configFile then
          [ "--config=${options.configFile}" ]
        else if options ? settings then
          [ "--config=${generator.generate "fuzzel.ini" options.settings}" ]
        else
          [];
      flags = dmenuFlags ++ logsFlags ++ configFlag;
    in {
      inherit (options) package;
      inherit flags;
    }
  );

  result = promise ({ results }: results.mkWrapper);

  meta = {
    maintainers = [];
  };
}
