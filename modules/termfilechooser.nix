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
        Settings to be injected into the wrapped package's configuration file.

        See the termfilechooser [documentation](https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser#configuration) for valid options.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        Configuration file to be injected into the wrapped package.

        See the termfilechooser [documentation](https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser#configuration) for valid options.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.xdg-desktop-portal-termfilechooser;
      description = "The xdg-desktop-portal-termfilechooser package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.toml {};
    in
    assert options ? settings != options ? configFile;
    inputs.mkWrapper {
      inherit (options) package;
      binaryPath = "$out/libexec/xdg-desktop-portal-termfilechooser";
      symlinks = {
        "$out/xdg-desktop-portal-termfilechooser/config" =
          if options ? configFile then
            options.configFile
          else
            (generator.generate "config" options.settings);
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  meta = {
    maintainers = [ "llakala" ];
  };
}
