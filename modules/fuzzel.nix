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
        Settings to be injected into the wrapped package's `fuzzel.ini`.

        See the documentation for valid options:
        https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.ini.5.scd

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `fuzzel.ini` file to be injected into the wrapped package.

        See the documentation for syntax and valid options:
        https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.ini.5.scd

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
        }).override
          { total = false; };
      description = ''
        Dmenu related flags to pass to fuzzel when using `settings`/`configFile`

        See the documentation for valid syntax and formatting of the related flags:
        https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.1.scd

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

        See the documentation for valid syntax and formatting of the related flags:
        https://codeberg.org/dnkl/fuzzel/src/branch/master/doc/fuzzel.1.scd

        Requires that either `settings`/`configFile` be set.
      '';
    };

    _configFlag = {
      type = types.listOf types.string;
      description = ''
        Implementation detail, please ignore!
      '';
      defaultFunc =
        { options, inputs }:
        let
          inherit (inputs.nixpkgs.pkgs) writeText;
          inherit (inputs.nixpkgs.lib.generators) toIni;
        in
        if options ? configFile then
          [ "--config=${options.configFile}" ]
        else if options ? settings then
          [ "--config=${writeText "fuzzel.ini" (toIni options.settings)}" ]
        else
          [];
    };
  };

  inputs.mkWrapper.overrides = {
    name.value = "fuzzel";
    package.computedValue = { inputs }: inputs.nixpkgs.pkgs.fuzzel;
    preWrap.computedValue =
      { options }:
      let
        inherit (builtins) head;
      in
      if options ? settings || options ? configFile then
        ''
          exec $out/bin/fuzzel --check-config ${head options._configFlag}
        ''
      else
        "";
    flags.computedValue =
      { options, inputs }:
      let
        inherit (inputs.nixpkgs.lib) optionals;
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
          else
            [];
        logsFlags =
          if options ? logFlags then
            optionals (options.logFlags ? logLevel) [ "--log-level=${options.logFlags.logLevel}" ]
            ++ optionals (options.logFlags ? colorize) [ "--log-colorize=${options.logFlags.colorize}" ]
            ++ optionals (options.logFlags ? noSyslog && options.logFlags.noSyslog) [ "--log-no-syslog" ]
            ++ optionals (options.logFlags ? printTiming && options.logFlags.printTming) [
              "--print-timing-info"
            ]
          else
            [];
      in
      options._configFlag ++ dmenuFlags ++ logsFlags;
  };

  impl =
    { options, inputs }:
    assert (
      if options ? dmenuFlags then
        (options ? settings || options ? configFile)
      else
        true
    );
    assert (
      if options ? logFlags then
        (options ? settings || options ? configFile)
      else
        true
    );
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {};
}
