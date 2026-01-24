{ adios }:
let
  inherit (adios) types;
in {
  name = "discordo";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's 'config.toml'.

        See the default configuration for valid options:
        https://github.com/ayn2op/discordo/blob/main/internal/config/config.toml

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the default configuration for valid options:
        https://github.com/ayn2op/discordo/blob/main/internal/config/config.toml

        Disjoint with the `settings` option.
      '';
    };

    tokenFile = {
      type = types.pathLike;
      description = ''
        A file containing a discord token which is read at runtime and injected into the wrapped package's environment.

        I recommend using a solution like [sops-nix](https://github.com/Mic92/sops-nix) or [agenix](https://github.com/ryantm/agenix) to encrypt your token.
      '';
    };

    # TODO: add impure variant when makeBinaryWrapper supports it
    flags = {
      type = types.listOf types.string;
      default = [];
      description = ''
        Flags to be automatically appended when running discordo.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.discordo;
      description = "The discordo package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      generator = inputs.nixpkgs.pkgs.formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package flags;
      preSymlink = ''
        mkdir -p $out/discordo/
      '';
      environment = {
        XDG_CONFIG_HOME = "$out";
        DISCORDO_TOKEN =
          if options ? tokenFile then
            {
              value = options.tokenFile;
              readFromFile = true;
            }
          else
            null;
      };
      symlinks = {
        "$out/discordo/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
      };
    };
}
