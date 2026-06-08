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
        Settings to be injected into the wrapped package's `bottom.toml`.

        See the bottom documentation for valid options:
        https://bottom.pages.dev/nightly/configuration/config-file/

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `bottom.toml` file to be injected into the wrapped package.

        See the bottom documentation for valid options:
        https://bottom.pages.dev/nightly/configuration/config-file/

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The bottom package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.bottom;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      binaryPath = "$out/bin/btm";
      symlinks = {
        "$out/bottom/bottom.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "bottom.toml" options.settings
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };
}
