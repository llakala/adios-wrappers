{ types, ... }:
{
  name = "termfilechooser";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's configuration file.

        See the termfilechooser documentation for valid options:
        https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser#configuration
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        Configuration file to be injected into the wrapped package.

        See the termfilechooser documentation for valid options:
        https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser#configuration
      '';
    };

    package = {
      type = types.derivation;
      description = "The xdg-desktop-portal-termfilechooser package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.xdg-desktop-portal-termfilechooser;
    };
  };

  impl =
    { options, inputs }:
    let
      generator = inputs.nixpkgs.pkgs.formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      binaryPath = "$out/libexec/xdg-desktop-portal-termfilechooser";
      preSymlink = ''
        mkdir -p $out/xdg-desktop-portal-termfilechooser
      '';
      symlinks = {
        "$out/xdg-desktop-portal-termfilechooser/config" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            (generator.generate "config" options.settings)
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };
}
