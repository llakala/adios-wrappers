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
        Settings to be injected into the wrapped package's `hyfetch.json`.

        Unwrapped hyfetch configurations can be created via:
        `hyfetch --config-file hyfetch.json --config`
        This can then be turned into a nix value:
        `nix-instantiate --eval -E 'builtins.fromJSON (builtins.readFile ./hyfetch.json)'`

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `hyfetch.json` file to be injected into the wrapped package.

        Unwrapped hyfetch configurations can be created via:
        `hyfetch --config-file hyfetch.json --config`

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The hyfetch package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.hyfetch;
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
        "$out/hyfetch/hyfetch.json" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "hyfetch.json" options.settings
          else
            null;
      };
      flags = optionals (options ? configFile || options ? settings) [
        "--config-file"
        "$out/hyfetch/hyfetch.json"
      ];
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
