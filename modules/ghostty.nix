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
        Options to be injected into the wrapped package's `config.ghostty`.

        See the ghostty [documentation](https://ghostty.org/docs/config).

        Disjoint with the `configFile` option.
      '';
      example = {
        cursor-color = "ffffff";
        cursor-text = "000000";
        background = "272822";
        foreground = "ffffff";
      };
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.ghostty` file to be injected into the wrapped package.

        See the ghostty [documentation](https://ghostty.org/docs/config).

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.ghostty;
      description = "The ghostty package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.keyValue {
        listsAsDuplicateKeys = true;
      };
    in
    inputs.mkWrapper {
      inherit (options) package;
      # Ensure ghostty.service uses the wrapped package.
      # We copy and replace the existing file to avoid permission errors.
      postWrap = ''
        cp $out/share/systemd/user/app-com.mitchellh.ghostty.service app-com.mitchellh.ghostty.service
        chmod +w app-com.mitchellh.ghostty.service
        substituteInPlace app-com.mitchellh.ghostty.service \
          --replace-fail "${options.package}/bin/ghostty" "$out/bin/ghostty"
        cp --remove-destination app-com.mitchellh.ghostty.service $out/share/systemd/user/app-com.mitchellh.ghostty.service
      '';
      symlinks = {
        "$out/ghostty/config.ghostty" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.ghostty" options.settings
          else
            null;
      };
      flags = [
        "--config-default-files=false"
        "--config-file=$out/ghostty/config.ghostty"
      ];
    };

  meta = {
    maintainers = [ "bivsk" ];
  };
}
