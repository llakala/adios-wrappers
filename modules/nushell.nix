{ types, assertions, ... } @ adios:
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

        See the nushell [documentation](https://www.nushell.sh/book/configuration.html) for valid options.
      '';
      mergeFunc = adios.lib.merge.strings.concatLines;
    };
    sourceFiles = {
      type = types.listOf types.pathLike;
      description = ''
        A list of paths to source in the `config.nu` file.
        This can be used to import extra files, and can be used with impurity
      '';
      mergeFunc = adios.lib.merge.lists.concat;
    };

    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Runtime dependencies to be injected into the wrapped package's path.
      '';
      mergeFunc = adios.lib.merge.lists.concat;
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.nushell;
      description = "The nushell package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "shellInit" "configFile")
  ];

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
    inputs.mkWrapper {
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
    maintainers = [ "Squawkykaka" ];
  };
}
