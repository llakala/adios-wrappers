{ adios }:
let
  inherit (adios) types;
in {
  name = "alacritty";

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

    package = {
      type = types.derivation;
      description = "The alacritty package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.alacritty;
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
      preSymlink = ''
        mkdir -p $out/alacritty
      '';
      symlinks = {
        "$out/alacritty/alacritty.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "alacritty.toml" options.settings
          else
            null;
      };
      flags = [
        "--config-file"
        "$out/alacritty/alacritty.toml"
      ];
    };
}
