{ types, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.jsonc`.

        See the [documentation](https://github.com/fastfetch-cli/fastfetch/wiki/Configuration) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.jsonc` file to be injected into the wrapped package.

        See the [documentation](https://github.com/fastfetch-cli/fastfetch/wiki/Configuration) for syntax and valid options.

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.fastfetch;
      description = "The fastfetch package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.json {};
    in
    assert options ? settings != options ? configFile;
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/fastfetch/config.jsonc" =
          if options ? configFile then
            options.configFile
          else
            generator.generate "config.jsonc" options.settings;
      };
      flags = [
        "--config"
        "$out/fastfetch/config.jsonc"
      ];
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
