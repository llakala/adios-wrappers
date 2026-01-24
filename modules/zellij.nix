{ adios }:
let
  inherit (adios) types;
in {
  name = "zellij";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  # The reason for there not being RFC42 options like `settings` or `layouts` is
  # because KDL is xml-like meaning there's no one way of it being encoded to
  # something like Nix.
  options = {
    configContents = {
      type = types.string;
      description = ''
        Config to be injected into the wrapped package's `config.kdl`.

        See the documentation for valid options:
        https://zellij.dev/documentation/configuration.html

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.kdl` file to be injected into the wrapped package.

        See the documentation for valid options:
        https://zellij.dev/documentation/configuration.html

        Disjoint with the `configContents` option.
      '';
    };

    layoutsContents = {
      type = types.attrsOf types.str;
      description = ''
        Custom layouts to be injected into the wrapped package.

        See the documentation to learn how to make custom layouts and use them:
        https://zellij.dev/documentation/layouts.html

        Disjoint with the `layoutsFiles` option.
      '';
    };
    layoutsFiles = {
      type = types.listOf types.pathLike;
      description = ''
        Files containing custom layouts to be injected into the wrapped package.

        See the documentation to learn how to make custom layouts and use them:
        https://zellij.dev/documentation/layouts.html

        Disjoint with the `layoutsContents` option.
      '';
    };

    themes = {
      type = types.attrsOf types.pathLike;
      description = ''
        Attribute set of themes to be injected into the wrapped package.

        See the zellij documentation to learn how to make custom themes and use them:
        https://zellij.dev/documentation/themes.html

        Each attribute name is used as the theme name. The corresponding value must be
        a folder or derivation whose top level contains a file named `<name>.kdl`.

        For example, an entry `themes.dracula = <drv>;` where `<drv>` contains
        `dracula.kdl` will result in `themes/dracula.kdl`.
      '';
    };

    package = {
      type = types.derivation;
      description = "The zellij package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.zellij;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (builtins) listToAttrs attrNames;
      inherit (inputs.nixpkgs.pkgs) writeText;
      optionalAttrs = cond: attrs: if cond then attrs else {};
    in
    assert !(options ? configContents && options ? configFile);
    assert !(options ? layoutsContents && options ? layoutsFiles);
    inputs.mkWrapper {
      inherit (options) package;
      preSymlink = ''
        mkdir -p $out/zellij-config/themes
        mkdir -p $out/zellij-config/layouts
      '';
      symlinks = {
        "$out/zellij-config/config.kdl" =
          if options ? configFile then
            options.configFile
          else if options ? configContents then
            writeText "config.kdl" options.configContents
          else
            null;
      }
      // (
        if options ? layoutsFiles then
          listToAttrs (
            map (path: {
              name = "$out/zellij-config/layouts/${baseNameOf path}";
              value = path;
            }) options.layoutsFiles
          )
        else if options ? layoutsContents then
          listToAttrs (
            map (path: {
              name = "$out/zellij-config/layouts/${path}.kdl";
              value = writeText path options.layoutsContents.${path};
            }) (attrNames options.layoutsContents)
          )
        else
          {}
      )
      // optionalAttrs (options ? themes) (
        listToAttrs (
          map (name: {
            name = "$out/zellij-config/themes/${name}.kdl";
            value = "${name}/${name}.kdl";
          }) (attrNames options.themes)
        )
      );
      environment = {
        ZELLIJ_CONFIG_DIR = "$out/zellij-config";
      };
    };
}
