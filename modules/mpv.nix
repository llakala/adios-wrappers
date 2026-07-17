{ types, ... }:
{
  inputs = {
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    scripts = {
      type = types.listOf types.derivation;
      description = ''
        Scripts to be added to the wrapped package.
        Packaged scripts from nixpkgs can be found in `mpvScripts`.
      '';
    };

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
      description = ''
        The mpv package to be wrapped.
        Note that this should use a `-unwrapped` variant.
      '';
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText mpv;
      inherit (inputs.nixpkgs.lib) generators concatStringsSep mapAttrsToList optionalString;
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

      configFile =
        if options ? configFile then
          options.configFile
        else if options ? settings then
          writeText "mpv.conf" (renderOptions options.settings)
        else
          null;
      keybindsFile =
        if options ? keybindsFile then
          options.keybindsFile
        else if options ? keybinds then
          writeText "input.conf" (renderKeybinds options.keybinds)
        else
          null;
    in
    assert !(options ? settings && options ? configFile);
    assert !(options ? keybinds && options ? keybindsFile);
    # We use the nixpkgs wrapper and not `mkWrapper` for a couple of reasons:
    # - The double wrapping would make `umpv` not work if wrapping their wrapper
    # - Wrapping with `mkWrapper` first and then the nixpkgs wrapper is surprisingly annoying
    # - Copying over the entire nixpkgs wrapper would increase the maintaince burden here
    mpv.override {
      mpv-unwrapped = options.package;
      scripts = options.scripts or [];
      extraMakeWrapperArgs = [
        "--add-flags"
        (
          "--no-config"
          + optionalString (configFile != null) " --include=${configFile}"
          + optionalString (keybindsFile != null) " --input-conf=${keybindsFile}"
        )
      ];
    };

  meta = {
    maintainers = [ "coca" ];
  };
}
