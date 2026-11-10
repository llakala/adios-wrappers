{
  types,
  merge,
  promise,
  assertions,
  ...
}:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `gitconfig`.

        See the git [documentation](https://git-scm.com/docs/git-config#_variables) for valid options.

        Disjoint with the `configFile` option.
      '';
      merge = merge.attrs.recursively;
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `gitconfig` file to be injected into the wrapped package.

        See the git [documentation](https://git-scm.com/docs/git-config#_configuration_file) on the syntax of this file.

        And the [documentation](https://git-scm.com/docs/git-config#_variables) on valid options.

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
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.git);
      description = "The git package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
    (assertions.disjoint "ignoredPaths" "ignoreFile")
  ];

  mutations = {
    "/starship".wrapperAttrs = promise (
      { result }:
      {
        environment.XDG_CONFIG_HOME = result;
      }
    );
  };

  inputs.mkWrapper.options = promise (
    { options, inputs }:
    let
      inherit (builtins) concatStringsSep;
      inherit (inputs.nixpkgs.pkgs) writeText formats;
      generator = formats.gitIni {};
    in {
      inherit (options) package;
      symlinks = {
        "$out/git/config" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config" options.settings
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
    }
  );

  result = promise ({ results }: results.mkWrapper);

  meta = {
    maintainers = [ "llakala" ];
  };
}
