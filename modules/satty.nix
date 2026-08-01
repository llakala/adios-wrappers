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
        Settings to be injected into the wrapped package's `config.toml`.

        See the Satty documentation for valid options:
        https://github.com/Satty-org/Satty#configuration-file

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the Satty documentation for syntax and valid options:
        https://github.com/Satty-org/Satty#configuration-file

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.satty;
      description = "The Satty package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.toml {};
    in
    assert options ? settings != options ? configFile;
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/satty/config.toml" =
          if options ? configFile then
            options.configFile
          else
            generator.generate "config.toml" options.settings;
      };
      flags = [
        "--config"
        "$out/satty/config.toml"
      ];
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
