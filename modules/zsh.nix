# TODO integration with zoxide, plugins, etc
{ types, ... } @ adios:
{
  name = "zsh";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    zshrc = {
      type = types.string;
      description = ''
        zsh script to be injected into the wrapped package's `.zshrc`.

        Disjoint with the `zshrcFiles` option.
      '';
      mutatorType = types.string;
      mergeFunc = adios.lib.merge.strings.concatLines;
    };
    extraZshrc = {
      type = types.string;
      description = ''
        zsh script to be injected at the end of the wrapped package's `.zshrc`.

        Disjoint with the `zshrcFiles` option.
      '';
      mutatorType = types.string;
      mergeFunc = adios.lib.merge.strings.concatLines;
    };
    zshrcFiles = {
      type = types.listOf types.pathLike;
      description = ''
        zsh files to be sourced in the wrapped package's `.zshrc` file.

        Disjoint with the `zshrc` option.
      '';
      mutatorType = types.listOf types.pathLike;
      mergeFunc = adios.lib.merge.lists.concat;
    };
    extraZshrcFiles = {
      type = types.listOf types.pathLike;
      description = ''
        zsh files to be sourced at the end of the wrapped package's `.zshrc` file.

        Disjoint with the `zshrc` option.:
      '';
      mutatorType = types.listOf types.pathLike;
      mergeFunc = adios.lib.merge.lists.concat;
    };

    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Runtime dependencies to be injected into the wrapped package's path.
      '';
      mutatorType = types.listOf types.pathLike;
      mergeFunc = adios.lib.merge.lists.concat;
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.zsh;
      description = "The zsh package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) makeBinPath;
      inherit (builtins) concatStringsSep;
      sourceFiles = files: (concatStringsSep "\n" (map (file: "source ${file}") files));
      zshrc =
        if options ? zshrcFiles then
          (sourceFiles options.zshrcFiles)
          + (
            if options ? extraZshrcFiles then
              "\n" + (sourceFiles options.extraZshrcFiles)
            else
              ""
          )
        else if options ? zshrc then
          options.zshrc
          + (
            if options ? extraZshrc then
              "\n" + options.extraZshrc
            else
              ""
          )
        else
          null;
    in
    assert !(options ? zshrc && options ? zshrcFiles);
    # extraZshrcFiles requires zshrcFiles to be set.
    assert (if options ? extraZshrcFiles && !(options ? zshrcFiles) then false else true);
    # extraZshrc requires zshrc to be set.
    assert (if options ? extraZshrc && !(options ? zshrc) then false else true);
    inputs.mkWrapper {
      inherit (options) package;
      wrapperArgs =
        if options ? extraPackages then "--prefix PATH : ${makeBinPath options.extraPackages}" else null;
      symlinks = {
        "$out/.zshrc" = if options ? zshrc || options ? zshrcFile then writeText ".zshrc" zshrc else null;
      };
      environment = {
        ZDOTDIR = if options ? zshrc || options ? zshrcFile then "$out" else null;
      };
    };
}
