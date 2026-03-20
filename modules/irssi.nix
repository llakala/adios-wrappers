{ types, ... }:
{
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    config = {
      type = types.string;
      description = ''
        The config to be injected into the wrapped package.

        See the documentation for valid options:
        https://irssi.org/documentation/settings/

        Disjoint with the `configDir` option.
      '';
    };
    configDir = {
      type = types.pathLike;
      description = ''
        The path of `.irssi` to be injected into the wrapped package.

        See the documentation for valid options:
        https://irssi.org/documentation/settings/

        Disjoint with the `config` option.
      '';
    };

    autoconnect = {
      type = types.union [
        (types.struct "autoconnectWithoutPassword" {
          server = types.string;
          port = types.string;
        })
        (types.struct "autoconnect" {
          server = types.string;
          password = types.string;
          port = types.string;
        })
      ];
      description = ''
        The server to be automatically connected to.
      '';
      example = {
        server = "irc.libera.chat";
        port = "6697";
        password = "hunter2"; # This is optional
      };
    };

    nickname = {
      type = types.string;
      description = "The default nickname to be injected into the wrapped package.";
    };

    hostname = {
      type = types.string;
      description = "The default hostname to be injected into the wrapped package.";
    };

    package = {
      type = types.derivation;
      description = "The irssi package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.irssi;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) optional optionals;
      homeFlag = optional (options ? configDir) "--home=$out/irssi";
      configFlag = optional (options ? config) "--config=$out/irssi/config";
      autoconnectFlag = optionals (options ? autoconnect) (
        [
          "--connect=${options.autoconnect.server}"
          "--port=${options.autoconnect.port}"
        ]
        ++ optional (options.autoconnect ? password) "--password=${options.autoconnect.password}"
      );
      nicknameFlag = optionals (options ? nickname) [
        "-n"
        options.nickname
      ];
      hostnameFlag = optionals (options ? hostname) [
        "-h"
        options.hostname
      ];
    in
    assert !(options ? configDir && options ? config);
    inputs.mkWrapper {
      name = "irssi";
      inherit (options) package;
      preSymlink =
        if options ? config then
          ''
            mkdir -p $out/irssi
          ''
        else
          null;
      symlinks = {
        "$out/irssi/config" = if options ? config then writeText "config" options.config else null;
        "$out/irssi" = if options ? configDir then options.configDir else null;
      };
      flags = homeFlag ++ configFlag ++ autoconnectFlag ++ nicknameFlag ++ hostnameFlag;
    };
}
