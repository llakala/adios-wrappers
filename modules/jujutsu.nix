{ types, ... }:
{
  name = "jujutsu";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.toml`.

        See the jujutsu documentation for valid options:
        https://docs.jj-vcs.dev/latest/config/

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the jujutsu documentation for valid options:
        https://docs.jj-vcs.dev/latest/config/

        Disjoint with the `settings` option.
      '';
    };

    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Packages to be automatically added to jujutsu's path. Can be used to enable 3-pane diff editing by using Meld or diffedit3.

        See the jujutsu documentation on how to achieve this:
        https://docs.jj-vcs.dev/latest/config/#experimental-3-pane-diff-editing
      '';
    };
    package = {
      type = types.derivation;
      description = "The jujutsu package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.jujutsu;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      inherit (inputs.nixpkgs.lib) makeBinPath;
      generator = formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      binaryPath = "$out/bin/jj";
      preSymlink = ''
        mkdir -p $out/jj-config
      '';
      symlinks = {
        "$out/jj-config/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
      };
      wrapperArgs =
        if options ? extraPackages then
          ''
            --prefix PATH : ${makeBinPath options.extraPackages}
          ''
        else
          "";
      environment = {
        JJ_CONFIG = "$out/jj-config";
      };
    };
}
