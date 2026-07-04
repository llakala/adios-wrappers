{ types, ... } @ adios:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be automatically appended when running ripgrep-all.

        See the documentation of valid flags:
        https://github.com/phiresky/ripgrep-all#flags

        Disjoint with the `configFile` option.
      '';
    };

    adapters = {
      type = types.listOf types.attrs;
      description = ''
        Custom adapters to be appended to the wrapped package's `config.jsonc` after the `configContents` option.

        See the documentation for valid options:
        https://github.com/phiresky/ripgrep-all/wiki#custom-adapters

        Disjoint with the `configFile` option.
      '';
      mutatorType = types.listOf types.attrs;
      mergeFunc = adios.lib.merge.lists.concat;
      example = [
        {
          name = "poppler";
          version = 1;
          description = "Uses pdftotext (from poppler-utils) to extract plain text from PDF files";

          extensions = [ "pdf" ];
          mimetypes = [ "application/pdf" ];

          binary = "pdftotext";
          args = [
            "-"
            "-"
          ];
          disabled_by_default = false;
          output_path_hint = "\${input_virtual_path}.txt.asciipagebreaks";
        }
      ];
    };

    configFile = {
      type = types.pathLike;
      description = ''
        `config.jsonc` file to be injected into the wrapped package.

        See the documentation for syntax and valid options:
        https://github.com/phiresky/ripgrep-all#flags

        The json schema can be also be accessed via `rga --rga-print-json-schema` for more formatting detail.

        Disjoint with the `flags` and `adapters` option.
      '';
    };

    package = {
      type = types.derivation;
      description = ''
        The `ripgrep-all` package to be wrapped.

        As `ripgrep-all` makes use of the `ripgrep` package (also available in adios-wrappers), you can change the ripgrep package to your own via an injection.

        Overrides can be accomplished in adios-wrappers in the following manner:

        1. Add the `ripgrep` wrapper to the module inputs:
        `inputs.ripgrep.from = { parent }: parent.ripgrep;`

        2. Set the package option to an overriden `ripgrep-all` package with the previously used input:
        `options.package.defaultFunc = { inputs }: inputs.nixpkgs.ripgrep-all.override { ripgrep = inputs.ripgrep; };`
      '';
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.ripgrep-all;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (builtins) toJSON;
      inherit (inputs.nixpkgs.pkgs) formats;
      inherit (inputs.nixpkgs.lib) optionals;
      generator = formats.json {};
    in
    assert !(options ? configFile && (options ? flags || options ? adapters));
    inputs.mkWrapper {
      inherit (options) package;
      flags = optionals (options ? flags) options.flags;
      symlinks = {
        "$out/ripgrep-all/config.jsonc" =
          if options ? adapters then
            generator.generate "config.jsonc" {
              custom_adapters = options.adapters;
            }
          else if options ? configFile then
            options.configFile
          else
            null;
      };
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    };

  meta = {
    maintainers = [ "mango" ];
  };
}
