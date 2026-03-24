{ types, ... } @ adios:
{
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.attrs;
      verify = adios.lib.disjointWith [ "configFile" ];
      description = ''
        Settings to be injected into the wrapped package's `config.jsonc`.

        See the documentation for valid options:
        https://github.com/Alexays/Waybar/wiki/Configuration

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      verify = adios.lib.disjointWith [ "settings" ];
      description = ''
        `config.jsonc` file to be injected into the wrapped package.

        See the documentation for syntax and valid options:
        https://github.com/Alexays/Waybar/wiki/Configuration

        Disjoint with the `settings` option.
      '';
    };

    barStyle = {
      type = types.string;
      verify = adios.lib.disjointWith [ "cssFile" ];
      description = ''
        CSS to be injected into the wrapped package's `style.css`.

        See the documentation for writing waybar themes:
        https://github.com/Alexays/Waybar/wiki/Styling

        Disjoint with the `cssFile` option.
      '';
    };
    cssFile = {
      type = types.pathLike;
      verify = adios.lib.disjointWith [ "barStyle" ];
      description = ''
        `style.css` file to be injected into the wrapped package.

        See the documentation for writing waybar themes:
        https://github.com/Alexays/Waybar/wiki/Styling

        Live reloading of themes can be accomplished with an impure path and options.interactiveEnv set to true.

        Disjoint with the `barStyle` option.
      '';
    };

    interactiveEnv = {
      type = types.bool;
      description = ''
        Sets GTK_DEBUG=interactive to launch the wrapped package with the GTK CSS Inspector.

        See the documentation for use of the inspection tool:
        https://developer.gnome.org/documentation/tools/inspector.html

        Can be used with an impure path in options.cssFile to enable live theme reloading.
      '';
    };

    package = {
      type = types.derivation;
      description = "The waybar package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.waybar;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib.generators) toJSON;
    in
    let
      configFlag =
        if options ? configFile then
          [ "--config=${options.configFile}" ]
        else if options ? settings then
          [ "--config=${writeText "config.jsonc" (toJSON options.settings)}" ]
        else
          [];
      styleFlag =
        if options ? cssFile then
          [ "--style=${options.cssFile}" ]
        else if options ? barStyle then
          [ "--style=${writeText "style.css" options.barStyle}" ]
        else
          [];
    in
    inputs.mkWrapper {
      name = "waybar";
      inherit (options) package;
      flags = configFlag ++ styleFlag;
      environment.GTK_DEBUG =
        if options ? interactiveEnv && options.interactiveEnv then "interactive" else null;
    };
}
