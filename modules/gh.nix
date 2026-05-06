{ types, ... }:
{
  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.yml`.

        See the documentation:
        https://cli.github.com/manual/gh_config

        Disjoint with the `configDir` option.
      '';
    };
    hosts = {
      type = types.attrs;
      description = ''
        Host information to be injected into the wrapped package's `hosts.yml`.

        Disjoint with the `configDir` option.
      '';
    };
    configDir = {
      type = types.pathLike;
      description = ''
        Folder containing gh configuration files to be injected into the wrapped package.

        This folder should contain a `config.yml` and/or a `hosts.yml`.

        Disjoint with the `settings` and `hosts` options.
      '';
    };
  };

  mutations = {
    "/git".settings =
      { options, inputs }:
      let
        inherit (inputs.nixpkgs.lib) getExe;
        finalWrapper = options {};
      in {
        credential."https://github.com".helper = "${getExe finalWrapper} auth git-credential";
      };
  };

  inputs.mkWrapper.overrides = {
    package.computedValue = { inputs }: inputs.nixpkgs.pkgs.gh;
    environment.value = {
      GH_CONFIG_DIR = "$out/gh";
    };
    preSymlink.computedValue =
      { options }:
      if options ? configDir then
        ""
      else
        ''
          mkdir -p $out/gh
        '';
    symlinks.computedValue =
      { options, inputs }:
      let
        inherit (builtins) mapAttrs;
        generator = inputs.nixpkgs.pkgs.formats.yaml {};
        mapBools = mapAttrs (
          _: value:
          if value == true then
            "enabled"
          else if value == false then
            "disabled"
          else
            value
        );
      in
      if options ? configDir then
        {
          "$out/gh" = options.configDir;
        }
      else
        {
          "$out/gh/config.yml" =
            if options ? settings then
              generator.generate "config" (mapBools options.settings)
            else
              null;
          "$out/gh/hosts.yml" =
            if options ? hosts then
              generator.generate "hosts" (mapBools options.hosts)
            else
              null;
        };
  };

  impl =
    { options, inputs }:
    assert !(options ? configDir && (options ? settings || options ? hosts));
    inputs.mkWrapper {};

  meta = {
    maintainers = [ "llakala" ];
  };
}
