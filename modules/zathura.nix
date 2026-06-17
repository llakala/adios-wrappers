{ types, ... } @ adios:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Options to be injected into the wrapped package's `zathurarc`.

        See the zathurarc documentation for the full list of options:
        {manpage}`zathurarc(5)`.

        Disjoint with the `sourceFiles` option.
      '';
      example = {
        default-bg = "#000000";
        default-fg = "#FFFFFF";
      };
      mutatorType = types.attrs;
      mergeFunc = adios.lib.merge.attrs.recursively;
    };
    keybinds = {
      type = types.attrs;
      description = ''
        Keybindings to be injected into the wrapped package's `zathurarc`.

        See the zathurarc documentation for the full list of possible mappings:
        {manpage}`zathurarc(5)`.

        You can create a mode-specific mapping by specifying the mode before the key:
        `"[normal] <C-b>" = "scroll left";`.

        Disjoint with the `sourceFiles` option.
      '';
      example = {
        D = "toggle_page_mode";
        "<Right>" = "navigate next";
        "[fullscreen] <C-i>" = "zoom in";
      };
      mutatorType = types.attrs;
      mergeFunc = adios.lib.merge.attrs.recursively;
    };
    sourceFiles = {
      type = types.listOf types.pathLike;
      description = ''
        A list of paths to source in the `zathurarc` file.
        This can be used to import extra files, and can be used with impurity.

        See the zathurarc documentation for valid options:
        {manpage}`zathurarc(5)`.

        Disjoint with `settings` and `keybinds` options.
      '';
      mutatorType = types.listOf types.pathLike;
      mergeFunc = adios.lib.merge.lists.concat;
    };

    package = {
      type = types.derivation;
      description = "The zathura package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.zathura;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (builtins) concatStringsSep listToAttrs;
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) isBool mapAttrsToList optionals optionalAttrs;
      inherit (inputs.nixpkgs.lib.trivial) boolToString;

      # copied from https://github.com/nix-community/home-manager/blob/master/modules/programs/zathura.nix#L12-19
      formatLine =
        let
          formatValue = v: if isBool v then boolToString v else toString v;
        in
        n: v: ''set ${n}	"${formatValue v}"'';

      formatKeybindLine = n: v: "map ${n}   ${toString v}";

      assembledConfig = concatStringsSep "\n" (
        if options ? sourceFiles then
          map (el: "include ${el}") options.sourceFiles
        else
          optionals (options ? settings) (mapAttrsToList formatLine options.settings)
          ++ optionals (options ? keybinds) (mapAttrsToList formatKeybindLine options.keybinds)
      );
    in
    assert !(options ? sourceFiles && (options ? settings || options ? keybinds));
    inputs.mkWrapper {
      name = "zathura";
      inherit (options) package;
      symlinks = {
        "$out/zathura/zathurarc" = writeText "zathurarc" assembledConfig;
      }
      // optionalAttrs (options ? sourceFiles) (
        listToAttrs (
          map (path: {
            name = "$out/zathura/${baseNameOf path}";
            value = path;
          }) options.sourceFiles
        )
      );
      flags = [
        "--config-dir"
        "$out/zathura"
      ];
    };

  meta = {
    maintainers = [ "bivsk" ];
  };
}
