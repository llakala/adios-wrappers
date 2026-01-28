{ types, ... }:
{
  name = "swayidle";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    configContents = {
      type = types.string;
      description = ''
        Settings to be injected into the wrapped package's `config` file.

        See the documentation for valid options: https://man.archlinux.org/man/swayidle.1

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config` file to be injected into the wrapped package.

        See the documentation for valid options: https://man.archlinux.org/man/swayidle.1

        Disjoint with the `configContents` option.
      '';
    };

    seatName = {
      type = types.string;
      description = "The seat name to be injected into the wrapped package's flags.";
    };

    package = {
      type = types.derivation;
      description = "The swayidle package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.swayidle;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      configFlag =
        if options ? configContent || options ? configFile then
          [
            "-C"
            "$out/config"
          ]
        else
          [];
      styleFlag =
        if options ? seat then
          [
            "-S"
            options.seat
          ]
        else
          [];
    in
    assert !(options ? configContents && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/config" =
          if options ? configContents then
            writeText "config" options.configContents
          else if options ? configFile then
            options.configFile
          else
            null;
      };
      flags = configFlag ++ styleFlag;
    };
}
