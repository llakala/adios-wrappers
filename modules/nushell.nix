{ types, ... } @ adios:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    shellInit = {
      type = types.string;
      description = ''
        Shell initialisation code to be injected into the wrapped package's `config.nu`.

        See the nushell documentation for valid options:
        https://www.nushell.sh/book/configuration.html
      '';
      mutatorType = types.string;
      mergeFunc = adios.lib.merge.strings.concatLines;
    };
    sourceFiles = {
      type = types.listOf types.pathLike;
      description = ''
        A list of paths to source in the `config.nu` file.
        This can be used to import extra files, and can be used with impurity
      '';
      mutatorType = types.listOf types.pathLike;
      mergeFunc = adios.lib.merge.lists.concat;
    };
    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Runtime dependencies to be injected into the wrapped package's path.
      '';
      mutatorType = types.listOf types.derivation;
      mergeFunc = adios.lib.merge.lists.concat;
    };
    package = {
      type = types.derivation;
      description = "The nushell package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.nushell;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (builtins) concatStringsSep;
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) makeBinPath;

      assembledConfig = concatStringsSep "\n" (
        (
          if options ? sourceFiles then
            map (el: "source ${el}") options.sourceFiles
          else
            []
        )
        ++ (
          if options ? shellInit then
            [ options.shellInit ]
          else
            []
        )
      );
    in
    assert !(options ? shellInit && options ? configFile);
    inputs.mkWrapper {
      name = "nu";
      inherit (options) package;
      wrapperArgs =
        if options ? extraPackages then "--prefix PATH : ${makeBinPath options.extraPackages}" else null;
      symlinks = {
        "$out/nushell/config.nu" = writeText "config.nu" assembledConfig;
      };
      flags = [
        "--config"
        "$out/nushell/config.nu"
      ];
    };

  meta = {
    maintainers = [ "squawky" ];
  };
}
