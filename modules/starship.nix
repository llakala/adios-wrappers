{ types, promise, assertions, ... } @ adios:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `starship.toml`.

        See the [documentation](https://starship.rs/config/) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `starship.toml` file to be injected into the wrapped package.

        See the [documentation](https://starship.rs/config/) for valid options.

        Disjoint with the `settings` option.
      '';
    };

    wrapperAttrs = {
      type = types.attrs;
      description = ''
        Attributes to be passed directly to the wrapped package's `mkWrapper` call.

        This is primarily an implementation detail of how the git module mutates the starship wrapper.
        Setting or mutating it yourself isn't recommended.
      '';
      default = promise (
        { options, inputs }:
        let
          inherit (inputs.nixpkgs.pkgs) formats;
          generator = formats.toml {};
        in {
          inherit (options) package;
          environment.STARSHIP_CONFIG =
            if options ? configFile then
              options.configFile
            else if options ? settings then
              generator.generate "starship.toml" options.settings
            else
              null;
        }
      );
      merge = adios.lib.inject; # essentially recursiveUpdate on the default
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.starship);
      description = "The starship package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  mutations = {
    "/fish".interactiveShellInit = promise (
      { options, inputs, result }:
      let
        inherit (inputs.nixpkgs.lib) getExe;
      in
      # fish
      ''
        ${getExe result} init fish --print-full-init \
          | string replace --all "${getExe options.package}" "${getExe result}" \
          | source
      ''
    );
  };

  inputs.mkWrapper.options = promise ({ options }: options.wrapperAttrs);
  result = promise ({ results }: results.mkWrapper);

  meta = {
    maintainers = [ "llakala" ];
  };
}
