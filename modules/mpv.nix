{ types, promise, assertions, ... }:
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

        See the [manual](https://mpv.io/manual/stable/) for valid options.

        Sets inside this option are treated as [profiles](https://mpv.io/manual/stable/#profiles):

        Disjoint with the `configFile` option.
      '';
      example = {
        volume-max = 150;
        gui = {
          profile-cond = ''p["player-operation-mode"]=="pseudo-gui"'';
          idle = "once";
        };
      };
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `mpv.conf` file to be injected into the wrapped package.

        See the [manual](https://mpv.io/manual/stable/) for syntax and valid options.

        Disjoint with the `settings` option.
      '';
    };

    keybinds = {
      type = types.attrs;
      description = ''
        Keybinds to be injected into the wrapped package's `input.conf`.

        See the [manual](https://mpv.io/manual/stable/#input-conf) for valid options.

        Disjoint with the `keybindsFile` option.
      '';
    };
    keybindsFile = {
      type = types.pathLike;
      description = ''
        `input.conf` file to be injected into the wrapped package.

        See the [manual](https://mpv.io/manual/stable/#input-conf) for syntax and valid options.

        Disjoint with the `keybinds` option.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.mpv-unwrapped);
      description = ''
        The mpv package to be wrapped.
        Note that this should use a `-unwrapped` variant.
      '';
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
    (assertions.disjoint "keybinds" "keybindsFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) mpv writeText linkFarm;
      inherit (inputs.nixpkgs.lib)
        attrsToList
        concatMapAttrsStringSep
        concatMapStrings
        optional
        optionalString
        ;
      inherit (builtins) typeOf stringLength isAttrs partition;

      # Some of this was copied from https://github.com/nix-community/home-manager/blob/master/modules/programs/mpv.nix
      renderOptionLine =
        { name, value }:
        let
          rendered =
            rec {
              int = toString value;
              float = int;
              bool = if value then "yes" else "no";
              string = value;
            }
            .${typeOf value};

          length = toString (stringLength rendered);
        in
        "${name}=%${length}%${rendered}\n";

      renderOptions = concatMapStrings renderOptionLine;

      renderProfile =
        { name, value }:
        ''

          [${name}]
        ''
        + renderOptions (attrsToList value);

      renderSettings =
        settings:
        let
          split = partition (kv: !(isAttrs kv.value)) (attrsToList settings);
        in
        renderOptions split.right
        + (optionalString (split.wrong != []) (concatMapStrings renderProfile split.wrong));

      renderKeybinds = concatMapAttrsStringSep "\n" (name: value: "${name} ${value}");

      configFile =
        if options ? configFile then
          options.configFile
        else if options ? settings then
          writeText "mpv.conf" (renderSettings options.settings)
        else
          null;
      keybindsFile =
        if options ? keybindsFile then
          options.keybindsFile
        else if options ? keybinds then
          writeText "input.conf" (renderKeybinds options.keybinds)
        else
          null;

      configDir = linkFarm "mpv-config" (
        (optional (configFile != null) {
          name = "mpv.conf";
          path = configFile;
        })
        ++ (optional (keybindsFile != null) {
          name = "input.conf";
          path = keybindsFile;
        })
      );
    in
    # We use the nixpkgs wrapper and not `mkWrapper` for a couple of reasons:
    # - The double wrapping would make `umpv` not work if wrapping their wrapper
    # - Wrapping with `mkWrapper` first and then the nixpkgs wrapper is surprisingly annoying
    # - Copying over the entire nixpkgs wrapper would increase the maintaince burden here
    mpv.override {
      mpv-unwrapped = options.package;
      scripts = options.scripts or [];
      extraMakeWrapperArgs = [
        "--add-flag"
        "--config-dir=${configDir}"
      ];
    }
  );

  meta = {
    maintainers = [ "coca" ];
  };
}
