{ adios }:
let
  inherit (adios) types;
in
{
  name = "nushell";

  inputs = {
    nixpkgs.path = "/nixpkgs";
    mkWrapper.path = "/mkWrapper";
  };

  options = {
    config = {
      type = types.str;
      description = ''
        Config to be injected into the wrapped package's `config.nu`.

        See the nushell documentation for valid options:
        https://www.nushell.sh/book/configuration.html

        Disjoint with the `configFile` option.
      '';
      mutatorType = types.str;
      mergeFunc =
        { mutators, options }:
        let
          inherit (builtins) attrValues concatStringsSep;
        in
        concatStringsSep "\n" (attrValues mutators);
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.nu` file to be injected into the wrapped package.

        See the nushell documentation on file syntax:
        https://www.nushell.sh/book/configuration.html

        Disjoint with the `config` option.
      '';
    };

    environment = {
      type = types.attrs;
      description = ''
        Attrset of environment variables to be injected into the
        wrapped packages `config.nu`.

        See the nushell documentation for valid options:
        https://www.nushell.sh/book/configuration.html

        Example:
        ```
        {
          HELLO = "test";
          FOO = "3";
        }
        ```

        Maps to:
        ```
        $env.HELLO = "test"
        $env.FOO = "3"

        Disjoint with the `environmentFile` option.
        ```
      '';
      mutatorType = types.attrs;
      mergeFunc = adios.lib.mergeFuncs.mergeAttrsRecursively;
    };
    environmentFile = {
      type = types.pathLike;
      description = ''
        `env.nu` file to be injected into the wrapped package.

        See the nushell documentaion on file sytax:
        https://www.nushell.sh/book/configuration.html

        Disjoint with the `environment` option.
      '';
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) concatStringsSep mapAttrsToList;
      inherit (inputs.nixpkgs.pkgs) writeText nushell;

      format =
        input: concatStringsSep "\n" (mapAttrsToList (name: value: "$env.${name} = \"${value}\"") input);

      generatedConfig = options.configFile or (writeText "config.nu" options.config);
      generatedEnv = options.environmentFile or (writeText "env.nu" (format options.environment));

    in
    assert !(options ? config && options ? configFile);
    assert !(options ? environment && options ? environmentFile);
    inputs.mkWrapper {
      package = nushell;
      binaryPath = "$out/bin/nu";
      flags = [
        "--config ${generatedConfig}"
        "--env-config ${generatedEnv}"
      ];
    };
}
