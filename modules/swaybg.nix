{ types, ... }:
{
  name = "swaybg";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    color = {
      type = types.string;
      description = "Hex formatted background color to be displayed by the wrapped package.";
      example = "ffffff";
    };

    backgroundImage = {
      type = types.pathLike;
      description = "Path to the background image to be displayed by the wrapped package.";
    };

    scalingMode = {
      type = types.string;
      description = ''
        Mode to determine how the wrapped package scales images.

        See the documentation for valid modes: https://man.archlinux.org/man/extra/swaybg/swaybg.1.en#OPTIONS
      '';
    };

    outputName = {
      type = types.string;
      description = "Name of the output to be used by the wrapped package.";
      example = "eDP-1";
    };

    package = {
      type = types.derivation;
      description = "The swaybg package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.swaybg;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.lib) optionals;
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        # Unecessary as `backgroundImage` can be passed directly to `-i` but this assists with debugging.
        "$out/backgroundImage" = if options ? backgroundImage then options.backgroundImage else null;
      };
      flags =
        (optionals (options ? color) [
          "-c"
          options.color
        ])
        ++ (optionals (options ? backgroundImage) [
          "-i"
          "$out/backgroundImage"
        ])
        ++ (optionals (options ? scalingMode) [
          "-m"
          options.scalingMode
        ])
        ++ (optionals (options ? outputName) [
          "-o"
          options.outputName
        ]);
    };
}
