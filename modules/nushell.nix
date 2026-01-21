{ adios }:
let
  inherit (adios) types;
in
{
  name = "nushell";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.string;
      description = ''
        Config to be injected into the wrapped package's `config.nu`.

        See the nushell documentation for valid options:
        https://www.nushell.sh/book/configuration.html

        Disjoint with the `configFile` option.
      '';
      mutatorType = types.string;
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
        ```

        Disjoint with the `environmentFile` option.
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

    package = {
      type = types.derivation;
      description = "The nushell package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.nushell;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) concatStringsSep mapAttrsToList;
      inherit (inputs.nixpkgs.pkgs) writeText;
      format =
        input: concatStringsSep "\n" (mapAttrsToList (name: value: "$env.${name} = \"${value}\"") input);

      configFlag =
        if options ? configFile then
          [ "--config ${options.configFile}" ]
        else if options ? settings then
          [ "--config ${writeText "config.nu" options.settings}" ]
        else
          [ ];
      envFlag =
        if options ? environmentFile then
          [ "--env-config ${options.enironmentFile} "]
        else if options ? environment then
          [ "--env-config ${writeText "env.nu" (format options.environment)}" ]
        else
          [ ];
    in
    assert !(options ? config && options ? configFile);
    assert !(options ? environment && options ? environmentFile);
    inputs.mkWrapper {
      package = options.package;
      binaryPath = "$out/bin/nu";
      flags = configFlag ++ envFlag;
    };
}
