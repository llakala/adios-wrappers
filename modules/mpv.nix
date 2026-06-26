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
        Settings to be injected into the wrapped package's `mpv.conf`.

        See the manual for valid options:
        https://mpv.io/manual/stable/

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `mpv.conf` file to be injected into the wrapped package.

        See the manual for syntax and valid options:
        https://mpv.io/manual/stable/

        Disjoint with the `settings` option.
      '';
    };

    keybinds = {
      type = types.attrs;
      description = ''
        Keybinds to be injected into the wrapped package's `input.conf`.

        See the manual for valid options:
        https://mpv.io/manual/stable/#input-conf

        Disjoint with the `keybindsFile` option.
      '';
    };
    keybindsFile = {
      type = types.pathLike;
      description = ''
        `input.conf` file to be injected into the wrapped package.

        See the manual for syntax and valid options:
        https://mpv.io/manual/stable/#input-conf

        Disjoint with the `keybinds` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.mpv-unwrapped;
      description = "The mpv package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) generators concatStringsSep mapAttrsToList;
      inherit (builtins) typeOf stringLength;

      # Most of this copied from https://github.com/nix-community/home-manager/blob/master/modules/programs/mpv.nix
      renderOption =
        option:
        rec {
          int = toString option;
          float = int;
          bool = if option then "yes" else "no";
          string = option;
        }
        .${typeOf option};

      renderOptionValue =
        value:
        let
          rendered = renderOption value;
          length = toString (stringLength rendered);
        in
        "%${length}%${rendered}";

      renderOptions = generators.toKeyValue {
        mkKeyValue = generators.mkKeyValueDefault { mkValueString = renderOptionValue; } "=";
        listsAsDuplicateKeys = true;
      };

      renderKeybinds =
        keybinds: concatStringsSep "\n" (mapAttrsToList (name: value: "${name} ${value}") keybinds);
    in
    assert !(options ? settings && options ? configFile);
    assert !(options ? keybinds && options ? keybindsFile);
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/mpv/mpv.conf" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            writeText "mpv.conf" (renderOptions options.settings)
          else
            null;
        "$out/mpv/input.conf" =
          if options ? keybindsFile then
            options.keybindsFile
          else if options ? keybinds then
            writeText "input.conf" (renderKeybinds options.keybinds)
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
