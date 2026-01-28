{ types, ... } @ adios:
{
  name = "git";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `gitconfig`.

        See the git documentation for valid options:
        https://git-scm.com/docs/git-config#_variables

        Disjoint with the `configFile` option.
      '';
      mutatorType = types.attrs;
      mergeFunc = adios.lib.merge.attrs.recursively;
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `gitconfig` file to be injected into the wrapped package.

        See the git documentation on the syntax of this file:
        https://git-scm.com/docs/git-config#_configuration_file

        And the documentation on valid options:
        https://git-scm.com/docs/git-config#_variables

        Disjoint with the `settings` option.
      '';
    };

    ignoredPaths = {
      type = types.listOf types.string;
      description = ''
        Extra path globs to be ignored automatically, along with the repo-specific `.gitignore`.

        Disjoint with the `ignoreFile` option.
      '';
    };
    ignoreFile = {
      type = types.pathLike;
      description = ''
        File containing extra path globs to be ignored automatically, along with the repo-specific `.gitignore`.

        Disjoint with the `ignoredPaths` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The git package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.git;
    };
  };

  mutations."/starship".wrapperAttrs =
    { options }:
    {
      environment.XDG_CONFIG_HOME = options {};
    };

  impl =
    { options, inputs }:
    let
      inherit (builtins) concatStringsSep;
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib.generators) toGitINI;
    in
    assert !(options ? settings && options ? configFile);
    assert !(options ? ignoredPaths && options ? ignoreFile);
    inputs.mkWrapper {
      name = "git"; # Default derivation name is git-with-svn
      inherit (options) package;
      preSymlink = ''
        mkdir -p $out/git
      '';
      symlinks = {
        "$out/git/config" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            (writeText "config" (toGitINI options.settings))
          else
            null;
        "$out/git/ignore" =
          if options ? ignoreFile then
            options.ignoreFile
          else if options ? ignoredPaths then
            writeText "ignore" (concatStringsSep "\n" options.ignoredPaths)
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };
}
