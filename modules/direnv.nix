{ types, ... }:
{
  name = "direnv";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };
  options = {
    package = {
      type = types.derivation;
      description = "The direnv package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.direnv;
    };

    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `direnv.toml`.

        See the direnv docs for valid options:
        {manpage}`direnv.toml(1)`.

        Disjoint with the `configFile` option.
      '';
    };

    configFile = {
      type = types.pathLike;
      description = ''
        `direnv.toml` file to be injected into the wrapped package.

        See the direnv documentation for valid options:
        {manpage}`direnv.toml(1)`.

        Disjoint with the `settings` option.
      '';
    };

    stdlib = {
      type = types.string;
      description = ''
        Custom stdlib definition to be injected into the wrapped packages `direnvrc`
      '';
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats writeText nix-direnv;
      generator = formats.toml {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      preSymlink = ''
        mkdir -p $out/direnv/lib
      '';

      symlinks = {
        "$out/direnv/direnv.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "direnv.toml" options.settings
          else
            null;

        # nix-direnv integration
        "$out/direnv/lib/hm-nix-direnv.sh" = "${nix-direnv}/share/nix-direnv/direnvrc";

        "$out/direnv/direnvrc" = if options ? stdlib then writeText "direnvrc" options.stdlib else null;
      };

      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  mutations."/fish".interactiveShellInit =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) getExe;
      finalWrapper = options {};
    in
    ''
      ${getExe finalWrapper} hook fish | source
    '';

  mutations."/nushell".shellInit =
    { inputs, options }:
    let
      inherit (inputs.nixpkgs.lib) getExe;
      finalWrapper = options {};
    in
    ''
      $env.config = ($env.config? | default {})
      $env.config.hooks = ($env.config.hooks? | default {})
      $env.config.hooks.pre_prompt = (
          $env.config.hooks.pre_prompt?
          | default []
          | append {||
              ${getExe finalWrapper} export json
              | from json --strict
              | default {}
              | items {|key, value|
                  let value = do (
                      {
                        "PATH": {
                          from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
                          to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
                        }
                      }
                      | merge ($env.ENV_CONVERSIONS? | default {})
                      | get ([[value, optional, insensitive]; [$key, true, true] [from_string, true, false]] | into cell-path)
                      | if ($in | is-empty) { {|x| $x} } else { $in }
                  ) $value
                  return [ $key $value ]
              }
              | into record
              | load-env
          }
      )
    '';

}
