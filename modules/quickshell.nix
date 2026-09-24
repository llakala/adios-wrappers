{ types, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    configDir = {
      type = types.pathLike;
      description = ''
        Folder containing quickshell configuration files to be injected into the wrapped package.

        This folder should contain a `shell.qml` file.

        See the Quickshell [docs](https://quickshell.org/docs/v0.3.0) for more information.
      '';
    };
    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.quickshell;
      description = "The quickshell package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/quickshell" = options.configDir;
      };
      flags = [
        "--path"
        "$out/quickshell"
      ];
      postWrap = ''
        rm $out/bin/qs
        ln $out/bin/quickshell $out/bin/qs
      '';
    };

  meta = {
    maintainers = [ "Squawkykaka" ];
  };
}
