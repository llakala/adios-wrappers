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
        Settings to be injected into the wrapped package's `btop.conf`.

        See the documentation for valid options:
        https://github.com/aristocratos/btop#configurability

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `btop.conf` file to be injected into the wrapped package.

        See the documentation for syntax and valid options:
        https://github.com/aristocratos/btop#configurability

        Disjoint with the `settings` option.
      '';
    };

    # TODO: Themes are located in $out/share/btop/themes
    # should provide a option here to be able to set them
    # though I don't know what route would be best for that

    package = {
      type = types.derivation;
      description = "The btop package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.btop;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) generators optionals;
      inherit (builtins) isBool isString;

      # Mostly copied from home-manager
      # https://github.com/nix-community/home-manager/blob/master/modules/programs/mpv.nix
      toKeyValue = generators.toKeyValue {
        mkKeyValue = generators.mkKeyValueDefault {
          mkValueString =
            v:
            if isBool v then
              (if v then "True" else "False")
            else if isString v then
              ''"${v}"''
            else
              toString v;
        } " = ";
      };
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/btop/btop.conf" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            writeText "btop.conf" (toKeyValue options.settings)
          else
            null;
      };
      flags = optionals (options ? configFile || options ? settings) [
        "--config"
        "$out/btop/btop.conf"
      ];
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
