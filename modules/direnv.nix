{ types, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `direnv.toml`.

        See the direnv [docs](https://manpages.ubuntu.com/manpages/focal/man1/direnv.toml.1.html) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `direnv.toml` file to be injected into the wrapped package.

        See the direnv [documentation](https://manpages.ubuntu.com/manpages/focal/man1/direnv.toml.1.html) for valid options.

        Disjoint with the `settings` option.
      '';
    };

    direnvrc = {
      type = types.string;
      description = ''
        Custom direnvrc definition to be injected into the wrapped packages `direnvrc`

        The syntax is described in the [documentation](https://direnv.net/#the-stdlib).
      '';
    };
    direnvrcFile = {
      type = types.string;
      description = ''
        `direnvrc` file to be copied into the wrapped package.

        The syntax is described in the [documentation](https://direnv.net/#the-stdlib).
      '';
    };

    nix-direnv = {
      type = types.nullOr types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.nix-direnv;
      description = ''
        The nix-direnv package to integrate with the wrapped package, or null for no integration.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.direnv;
      description = "The direnv package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
    (assertions.disjoint "direnvrc" "direnvrcFile")
  ];

  mutations."/fish".interactiveShellInit =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) getExe;
      finalWrapper = options {};
    in
    ''
      ${getExe finalWrapper} hook fish | source
    '';

  # shell configuration for nushell, uses home managers config since
  # direnv doesnt have a command to generate
  mutations."/nushell".shellInit =
    { options, inputs }:
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

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats writeText;
      inherit (options) nix-direnv;
      generator = formats.toml {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/direnv/direnv.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "direnv.toml" options.settings
          else
            null;
        # nix-direnv integration
        "$out/direnv/lib/hm-nix-direnv.sh" =
          if nix-direnv != null then "${nix-direnv}/share/nix-direnv/direnvrc" else null;
        "$out/direnv/direnvrc" =
          if options ? direnvrcFile then
            options.direnvrcFile
          else if options ? direnvrc then
            writeText "direnvrc" options.direnvrc
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  meta = {
    maintainers = [ "Squawkykaka" ];
  };
}
