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
        Settings to be injected into the wrapped package's `config.toml`.

        See the [documentation](https://docs.helix-editor.com/configuration.html).

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the [documentation](https://docs.helix-editor.com/configuration.html) for valid options.

        Disjoint with the `config` option.
      '';
    };

    themes = {
      type = types.attrsOf types.attrs;
      description = ''
        An attrset of custom themes, mapping the name of a theme to its settings.

        See the [documentation](https://docs.helix-editor.com/themes.html) for valid options.

        Disjoint with the `themeDir` option.
      '';
    };
    themeDir = {
      type = types.pathLike;
      description = ''
        Folder containing theme configuration files to be injected into the wrapped package.

        This folder should contain one or multiple `$theme_name.toml` files.

        Disjoint with the `themes` option.
      '';
    };

    languages = {
      type = types.attrs;
      description = ''
        Language config to be injected into the wrapped package's `languages.toml`.

        See the [documentation](https://docs.helix-editor.com/languages.html) for valid options.

        Disjoint with the `languagesFile` option.
      '';
    };
    languagesFile = {
      type = types.pathLike;
      description = ''
        `languages.toml` file to be injected into the wrapped package.

        See the [documentation](https://docs.helix-editor.com/languages.html) on valid options.

        Disjoint with the `languages` option.
      '';
    };

    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Packages to be automatically added to helix's path. Mainly used to set language servers and formatters.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.helix;
      description = "The helix package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
    (assertions.disjoint "themes" "themeDir")
    (assertions.disjoint "languages" "languagesFile")
  ];

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      inherit (builtins) listToAttrs attrNames;
      inherit (inputs.nixpkgs.lib) makeBinPath;
      generator = formats.toml {};
      generatedThemes =
        if options ? themeDir then
          {
            "$out/helix/themes" = options.themeDir;
          }
        else if options ? themes then
          listToAttrs (
            map (name: {
              name = "$out/helix/themes/${name}.toml";
              value = generator.generate "${name}.toml" options.themes.${name};
            }) (attrNames options.themes)
          )
        else
          {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/helix/config.toml" =
          if options ? configFile then
            options.settingsFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
        "$out/helix/languages.toml" =
          if options ? languagesFile then
            options.languagesFile
          else if options ? languages then
            generator.generate "languages.toml" options.languages
          else
            null;
      }
      // generatedThemes;

      wrapperArgs =
        if options ? extraPackages then
          ''
            --prefix PATH : ${makeBinPath options.extraPackages}
          ''
        else
          "";
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  meta = {
    maintainers = [ "Squawkykaka" ];
  };
}
