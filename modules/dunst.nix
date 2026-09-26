{ types, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    configContents = {
      type = types.string;
      description = ''
        Settings to be injected into the wrapped package's `dunstrc`.

        See the [documentation](https://dunst-project.org/documentation/) for syntax and valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `dunstrc` file to be injected into the wrapped package.

        See the [documentation](https://dunst-project.org/documentation/) for syntax and valid options.

        Disjoint with the `configContents` option.
      '';
    };

    dropinFiles = {
      type = types.attrsOf types.pathLike;
      description = ''
        `*.conf` files to be injected into the wrapped package alongside the main configuration.

        See the [documentation](https://dunst-project.org/documentation/dunst/#FILES) for syntax and valid options.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.dunst;
      description = "The dunst package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "configContents" "configFile")
  ];

  impl =
    { options, inputs }:
    let
      inherit (builtins) attrNames listToAttrs;
      inherit (inputs.nixpkgs.pkgs) writeText;
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/dunst/dunstrc" =
          if options ? configFile then
            options.configFile
          else if options ? configContents then
            writeText "dunstrc" options.configContents
          else
            null;
      }
      // (
        if options ? dropinFiles then
          listToAttrs (
            map (name: {
              name = "$out/dunst/dunstrc.d/${name}";
              value = options.dropinFiles.${name};
            }) (attrNames options.dropinFiles)
          )
        else
          {}
      );

      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  meta = {
    maintainers = [];
  };
}
