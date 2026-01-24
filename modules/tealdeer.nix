{ adios }:
let
  inherit (adios) types;
in {
  name = "tealdeer";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.toml`.

        See the tealdeer documentation:
        https://tealdeer-rs.github.io/tealdeer/config.html

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the tealdeer documentation:
        https://tealdeer-rs.github.io/tealdeer/config.html

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The tealdeer package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.tealdeer;
    };
  };

  impl =
    { options, inputs }:
    let
      generator = inputs.nixpkgs.pkgs.formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      binaryPath = "$out/bin/tldr";
      preSymlink = ''
        mkdir -p $out/tealdeer-config
      '';
      symlinks = {
        "$out/tealdeer-config/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
      };
      environment = {
        TEALDEER_CONFIG_DIR = "$out/tealdeer-config";
      };
    };
}
