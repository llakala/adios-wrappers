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
        Settings to be injected into the wrapped package's `config.jsonc`.

        See the documentation for valid options:
        https://github.com/fastfetch-cli/fastfetch/wiki/Configuration

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.jsonc` file to be injected into the wrapped package.

        See the documentation for syntax and valid options:
        https://github.com/fastfetch-cli/fastfetch/wiki/Configuration

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The fastfetch package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.fastfetch;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      inherit (inputs.nixpkgs.lib) optionals;
      generator = formats.json {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/fastfetch/config.jsonc" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.jsonc" options.settings
          else
            null;
      };
      flags = optionals (options ? configFile || options ? settings) [
        "--config"
        "$out/fastfetch/config.jsonc"
      ];
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
