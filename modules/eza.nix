{ types, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
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

    package = {
      type = types.derivation;
      description = "The eza package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.eza;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.json {};
    in
    assert !(options ? themeConfig && options ? themeFile);
    inputs.mkWrapper {
      inherit (options) package flags;
      symlinks = {
        "$out/eza-config/theme.yml" =
          if options ? themeFile then
            options.themeFile
          else if options ? themeConfig then
            generator.generate "theme.yml" options.themeConfig
          else
            null;
      };
      environment = {
        EZA_CONFIG_HOME = "$out/eza-config";
      };
    };

  meta = {
    maintainers = [ "mango" ];
  };
}
