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
        Settings to be injected into the wrapped package's `wiremix.toml`.

        See the documentation for syntax and valid options:
        https://github.com/tsowell/wiremix/blob/main/wiremix.toml

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `wiremix.toml` file to be injected into the wrapped package.

        See the documentation for syntax and valid options:
        https://github.com/tsowell/wiremix/blob/main/wiremix.toml

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.wiremix;
      description = "The wiremix package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs) pkgs;
      generator = pkgs.formats.toml {};
    in
    assert options ? settings != options ? configFile;
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/wiremix/wiremix.toml" =
          if options ? configFile then
            options.configFile
          else
            generator.generate "wiremix.toml" options.settings;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  meta = {
    maintainers = [ "mango" ];
  };
}
