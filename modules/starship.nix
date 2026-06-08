{ types, ... } @ adios:
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

        See the documentation for valid options:
        https://starship.rs/config/

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `starship.toml` file to be injected into the wrapped package.

        See the documentation for valid options:
        https://starship.rs/config/

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
      mutators = []; # Hack to make the mergeFunc be called with no mutators
      mutatorType = types.attrs;
      mergeFunc =
        { mutators, options, inputs }:
        let
          inherit (inputs.nixpkgs.lib) recursiveUpdate;
          inherit (inputs.nixpkgs.pkgs) formats;
          inherit (adios.lib) merge;
          generator = formats.toml {};
          default =
            assert !(options ? settings && options ? configFile);
            {
              inherit (options) package;
              environment.STARSHIP_CONFIG =
                if options ? configFile then
                  options.configFile
                else if options ? settings then
                  generator.generate "starship.toml" options.settings
                else
                  null;
            };
        in
        # Allow mutators to change the default value, with the mutators taking
        # priority if the key is the same
        recursiveUpdate default (merge.attrs.recursively { inherit mutators; });
    };

    package = {
      type = types.derivation;
      description = "The starship package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.starship;
    };
  };

  mutations."/fish".interactiveShellInit =
    { options, inputs }:
    let
      finalWrapper = options {};
      inherit (inputs.nixpkgs.lib) getExe;
    in
    # fish
    ''
      ${getExe finalWrapper} init fish --print-full-init | source
    '';

  impl = { options, inputs }: inputs.mkWrapper options.wrapperAttrs;

  meta = {
    maintainers = [ "llakala" ];
  };
}
