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
  };

  inputs.mkWrapper.overrides = {
    package.computedValue = { inputs }: inputs.nixpkgs.pkgs.bottom;
    binaryPath.value = "$out/bin/btm";
    preSymlink.value = ''
      mkdir -p $out/bottom
    '';
    environment.value = {
      XDG_CONFIG_HOME = "$out";
    };
    symlinks.computedValue =
      { options, inputs }:
      let
        generator = inputs.nixpkgs.pkgs.formats.toml {};
      in {
        "$out/bottom/bottom.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "bottom.toml" options.settings
          else
            null;
      };
  };

  impl =
    { options, inputs }:
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {};
}
