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
        Settings to be injected into the wrapped package's `config.toml`.

        See the matugen docs for valid options:
        https://iniox.github.io/#matugen/configuration

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the matugen docs for valid options:
        https://iniox.github.io/#matugen/configuration

        Disjoint with the `settings` option.
      '';
    };
    package = {
      type = types.derivation;
      description = "The matugen package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.matugen;
    };
  };

  impl =
    { options, inputs }:
    let
      generator = inputs.nixpkgs.pkgs.formats.toml {};
    in
    assert !(options ? configFile && options ? settings);
    inputs.mkWrapper {
      inherit (options) package;
      preSymlink = ''
        mkdir -p $out/matugen
      '';
      symlinks = {
        "$out/matugen/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
      };
      flags = [
        "-c"
        "$out/matugen/config.toml"
      ];
    };
}
