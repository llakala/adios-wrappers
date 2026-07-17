{ types, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.toml`.

        See the documentation for syntax and valid options:
        https://github.com/Notarin/hayabusa/blob/main/CONFIGURATION.md

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the documentation for syntax and valid options:
        https://github.com/Notarin/hayabusa/blob/main/CONFIGURATION.md

        Disjoint with the `settings` option.
      '';
    };

    luaContents = {
      type = types.string;
      description = ''
        Lua code to be injected into the wrapped package's `config.lua`.

        See the default lua file for a general idea of expected contents and formatting.  
        https://github.com/Notarin/hayabusa/blob/main/src/config/default.lua

        Disjoint with the `luaFile` option.
      '';
    };
    luaFile = {
      type = types.pathLike;
      description = ''
        `config.lua` file to be injected into the wrapped package.

        See the default lua file for a general idea of expected contents and formatting.  
        https://github.com/Notarin/hayabusa/blob/main/src/config/default.lua

        Disjoint with the `luaContents` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.hayabusa;
      description = "The hayabusa package to be wrapped";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs) pkgs;
      inherit (inputs.nixpkgs.pkgs) writeText;
      generator = pkgs.formats.toml {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/hayabusa/config.lua" =
          if options ? luaFile then
            options.luaFile
          else if options ? luaContents then
            writeText "config.lua" options.luaContents
          else
            null;
        "$out/hayabusa/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  meta = {
    maintainers = [ "mango" ];
  };
}
