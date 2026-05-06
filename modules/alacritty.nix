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
        Settings to be injected into the wrapped package's `alacritty.toml`.

        See the alacritty documentation:
        https://alacritty.org/config-alacritty.html

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `alacritty.toml` file to be injected into the wrapped package.

        See the alacritty documentation:
        https://alacritty.org/config-alacritty.html

        Disjoint with the `settings` option.
      '';
    };
  };

  inputs.mkWrapper.overrides = {
    package.computedValue = { inputs }: inputs.nixpkgs.pkgs.alacritty;
    preSymlink.value = ''
      mkdir -p $out/alacritty
    '';
    flags.value = [
      "--config-file"
      "$out/alacritty/alacritty.toml"
    ];
    symlinks.computedValue =
      { options, inputs }:
      let
        generator = inputs.nixpkgs.pkgs.formats.toml {};
      in {
        "$out/alacritty/alacritty.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "alacritty.toml" options.settings
          else
            null;
      };
  };

  impl =
    { options, inputs }:
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper;
}
