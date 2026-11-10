{ types, promise, merge, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    configFiles = {
      type = types.listOf types.pathLike;
      description = ''
        A list of `.kdl` files that are included in the wrapped package's config.

        See the niri [documentation](https://github.com/niri-wm/niri/wiki/Configuration:-Introduction) for syntax and valid options.
      '';
      merge = merge.lists.concat;
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.niri);
      description = "The niri package to be wrapped.";
    };
  };

  inputs.mkWrapper.options = promise (
    { options, inputs }:
    let
      inherit (builtins) concatStringsSep head length;
      inherit (inputs.nixpkgs.pkgs) writeText;

      configPath =
        if length options.configFiles == 1 then
          head options.configFiles
        else
          writeText "config.kdl" (
            concatStringsSep "\n" (map (file: ''include "${file}"'') options.configFiles)
          );
    in {
      inherit (options) package;
      # Hack modified and gotten from https://github.com/Lassulus/wrappers/blob/main/modules/niri/module.nix
      postWrap = ''
        cp $out/share/systemd/user/niri.service niri.service
        chmod +w niri.service
        cat >> niri.service<<EOF
        [Service]
        ExecStart=
        ExecStart=$out/bin/niri --session
        ExecReload=$out/bin/niri msg action load-config-file --path ${configPath}
        X-ReloadIfChanged=true
        [Unit]
        X-Reload-Triggers=${configPath}
        EOF
        cp --remove-destination niri.service $out/share/systemd/user/niri.service
      '';
      environment = {
        NIRI_CONFIG = configPath;
      };
    }
  );

  result = promise (
    # TODO: use an assertion that guarantees configFiles is set
    { results, options }: if options ? configFiles then results.mkWrapper else options.package
  );

  meta = {
    maintainers = [ "coca" ];
  };
}
