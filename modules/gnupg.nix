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
        Settings to be injected into the wrapped package's `gpg.conf`.

        See the gnupg manual:
        https://www.gnupg.org/documentation/manuals/gnupg/GPG-Options.html

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `gpg.conf` file to be injected into the wrapped package.

        See the gnupg manual:
        https://www.gnupg.org/documentation/manuals/gnupg/GPG-Options.html

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.gnupg;
      description = "The gnupg package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) generators isString optionals optionalString;
      # Copied from https://github.com/nix-community/home-manager/blob/master/modules/programs/gpg.nix#L19-L25
      toKeyValue =
        settings:
        generators.toKeyValue {
          mkKeyValue = key: value: if isString value then "${key} ${value}" else optionalString value key;
          listsAsDuplicateKeys = true;
        } settings;
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/gnupg/gpg.conf" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            writeText "gpg.conf" (toKeyValue options.settings)
          else
            null;
      };
      flags = optionals (options ? configFile || options ? settings) [
        "--options"
        "$out/gnupg/gpg.conf"
      ];
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
