{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Options to be injected into the wrapped package's `config.ghostty`.

        See the ghostty [documentation](https://ghostty.org/docs/config).

        Disjoint with the `configFile` option.
      '';
      example = {
        cursor-color = "ffffff";
        cursor-text = "000000";
        background = "272822";
        foreground = "ffffff";
      };
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.ghostty` file to be injected into the wrapped package.

        See the ghostty [documentation](https://ghostty.org/docs/config).

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.ghostty);
      description = "The ghostty package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (builtins) concatStringsSep;
      inherit (inputs.nixpkgs.pkgs) formats writeShellScript;
      inherit (inputs.nixpkgs.lib) optional;
      generator = formats.keyValue {
        listsAsDuplicateKeys = true;
      };

      configPath =
        if options ? configFile then
          options.configFile
        else if options ? settings then
          generator.generate "config.ghostty" options.settings
        else
          null;

      defaultFilesFlag = [ "--config-default-files=false" ];
      configFlag = optional (configPath != null) "--config-file=${configPath}";

      # Ghostty's `+action` subcommands do not parse standard configuration flags, which
      # cause actions to silently fail.
      # Rather than unconditionally passing configuration flags to `mkWrapper`, check to see if
      # an action is being called.
      # Unfortunately, this causes `+show-config` and `+validate-config` actions to fall back to the
      # default configuration file, since `--config-file` is not parsed when calling an action.
      dispatcher = writeShellScript "ghostty" ''
        case "''${1-}" in
          +*) exec -a "$0" ${options.package}/bin/ghostty "$@" ;;
        esac
        exec -a "$0" ${options.package}/bin/ghostty ${
          concatStringsSep " " (defaultFilesFlag ++ configFlag)
        } "$@"
      '';
    in
    inputs.mkWrapper {
      inherit (options) package;
      # The dispatcher below stands in for the binary wrapper `mkWrapper` would build.
      binaryPaths = [];
      # Ensure ghostty.service uses the wrapped package.
      # We copy and replace the existing file to avoid permission errors.
      postWrap = ''
        cp $out/share/systemd/user/app-com.mitchellh.ghostty.service app-com.mitchellh.ghostty.service
        chmod +w app-com.mitchellh.ghostty.service
        substituteInPlace app-com.mitchellh.ghostty.service \
          --replace-fail "${options.package}/bin/ghostty" "$out/bin/ghostty"
        cp --remove-destination app-com.mitchellh.ghostty.service $out/share/systemd/user/app-com.mitchellh.ghostty.service

        rm $out/bin/ghostty
        install -m555 ${dispatcher} $out/bin/ghostty
      '';
    }
  );

  meta = {
    maintainers = [ "bivsk" ];
  };
}
