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
        Settings to be injected into the wrapped package's `btop.conf`.

        See the [documentation](https://github.com/aristocratos/btop#configurability) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `btop.conf` file to be injected into the wrapped package.

        See the [documentation](https://github.com/aristocratos/btop#configurability) for syntax and valid options.

        Disjoint with the `settings` option.
      '';
    };

    themes = {
      type = types.attrsOf types.pathLike;
      description = "Theme files to be injected into the wrapped package's themes directory.";
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.btop;
      description = "The btop package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) generators optionals optionalAttrs;
      inherit (builtins) isBool isString attrNames listToAttrs;

      # Mostly copied from home-manager
      # https://github.com/nix-community/home-manager/blob/master/modules/programs/mpv.nix
      toKeyValue = generators.toKeyValue {
        mkKeyValue = generators.mkKeyValueDefault {
          mkValueString =
            v:
            if isBool v then
              (if v then "True" else "False")
            else if isString v then
              ''"${v}"''
            else
              toString v;
        } " = ";
      };
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/btop/btop.conf" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            writeText "btop.conf" (toKeyValue options.settings)
          else
            null;
      }
      // optionalAttrs (options ? themes) (
        listToAttrs (
          map (name: {
            name = "$out/btop/themes/${name}";
            value = options.themes.${name};
          }) (attrNames options.themes)
        )
      );
      flags =
        optionals (options ? configFile || options ? settings) [
          "--config"
          "$out/btop/btop.conf"
        ]
        ++ optionals (options ? themes) [
          "--themes-dir"
          "$out/btop/themes"
        ];
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
