{ types, ... }:
{
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    # TODO: add impure variant when makeBinaryWrapper supports it
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be appended by default when running eza.
      '';
    };

    themes = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `theme.yml`.

        See `https://github.com/eza-community/eza/blob/main/man/eza_colors-explanation.5.md` for valid options

        Disjoint with the `themeFile` option.
      '';
    };
    themeFile = {
      type = types.pathLike;
      description = ''
        `theme.yml` file to be injected into the wrapped package.

        See `https://github.com/eza-community/eza/blob/main/man/eza_colors-explanation.5.md` for valid options

        Disjoint with the `themeConfig` option.
      '';
    };
  };

  inputs.mkWrapper.overrides = {
    package.computedValue = { inputs }: inputs.nixpkgs.pkgs.eza;
    flags.computedValue = { options }: options.flags;
    preSymlink.value = ''
      mkdir -p $out/eza-config
    '';
    environment.value = {
      EZA_CONFIG_HOME = "$out/eza-config";
    };
    symlinks.computedValue =
      { options, inputs }:
      let
        inherit (inputs.nixpkgs.pkgs) writeText;
        inherit (inputs.nixpkgs.lib.generators) toJSON;
      in {
        "$out/eza-config/theme.yml" =
          if options ? themeFile then
            options.themeFile
          else if options ? themeConfig then
            writeText "theme" (toJSON options.themeConfig)
          else
            null;
      };
  };

  impl =
    { options, inputs }:
    assert !(options ? themeConfig && options ? themeFile);
    inputs.mkWrapper {};
}
