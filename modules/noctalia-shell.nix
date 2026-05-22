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

        See the noctalia docs for valid options:
        https://docs.noctalia.dev/v5

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the noctalia docs for valid options:
        https://docs.noctalia.dev/v5

        Disjoint with the `settings` option.
      '';
    };
    package = {
      type = types.derivation;
      description = "The noctalia package to be wrapped.";
      defaultFunc =
        { inputs }:
        inputs.nixpkgs.warn "adios-wrappers: noctalia-shell from nixpkgs is outdated and cannot be wrapped." inputs.nixpkgs.pkgs.noctalia-shell;
    };
  };

  impl =
    { options, inputs }:
    let
      generator = inputs.nixpkgs.pkgs.formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      name = "noctalia";
      inherit (options) package;
      preSymlink = ''
        mkdir -p $out/noctalia
      '';
      symlinks = {
        "$out/noctalia/noctalia.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate options.settings
          else
            null;
      };
      environment = {
        NOCTALIA_CONFIG_HOME = "$out";
      };
    };
}
