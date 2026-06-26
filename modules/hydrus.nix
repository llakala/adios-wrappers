{ types, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    clientFlags = {
      type = types.listOf types.string;
      description = ''
        List of hydrus-client flags to pass to hydrus client on startup.

        Note that paths passed to db_dir/temp_dir should be writable (not in the nix store)

        See the documentation for valid syntax and formatting of the related flags:
        https://hydrusnetwork.github.io/hydrus/launch_arguments.html
      '';
    };
    serverFlags = {
      type = types.listOf types.string;
      description = ''
        List of hydrus-server flags to pass to hydrus server on startup.

        These flags only apply to hydrus-server, and are not required for basic client-only use, see:
        https://hydrusnetwork.github.io/hydrus/youDontWantTheServer.html

        Note that paths passed to db_dir/temp_dir should be writable (not in the nix store)

        See the documentation for valid syntax and formatting of the related flags:
        https://hydrusnetwork.github.io/hydrus/launch_arguments.html
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.hydrus;
      description = "The hydrus package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (builtins) concatStringsSep;
      mapFlags = flags: concatStringsSep " " (map (flag: "--add-flag \"${flag}\"") flags);
    in
    inputs.mkWrapper {
      inherit (options) package;
      binaryName = "hydrus-client";
      flags = if options ? clientFlags then options.clientFlags else [];
      postWrap =
        if options ? serverFlags then
          ''
            wrapProgram $out/bin/hydrus-server ${mapFlags options.serverFlags}
          ''
        else
          "";
    };

  meta = {
    maintainers = [ "mango" ];
  };
}
