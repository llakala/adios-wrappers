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

        Disjoint with the `configContents` and `configFile` option.
      '';
    };

    configContents = {
      type = types.attrs;
      # Tried finding a better reference for the schema but the only other option is struct doc which is includes CLI-only options
      description = ''
        Flags to automatically appended when running ripgrep-all set via `config.jsonc`.

        See the documentation of valid flags:
        https://github.com/phiresky/ripgrep-all#flags

        The json schema can be also be accessed via `rga --rga-print-json-schema` for more formatting detail.

        Custom adapters in `config.jsonc` are set via the `configAdapters` options.

        Disjoint with the `flags` and `configFile` option.
      '';
    };
    configAdapters =
      let
        adapterStruct =
          (types.struct "adapter" {
            name = types.string;
            version = types.int;
            description = types.string;

            extensions = types.listOf types.string;
            mimetypes = types.listOf types.string;

            binary = types.union [
              types.pathLike
              types.string
            ];
            args = types.listOf types.string;
            disabled_by_default = types.bool;
            match_only_by_mime = types.bool;
            output_path_hint = types.string;
          }).override
            { total = false; };
      in {
        type = types.listOf adapterStruct;
        description = ''
          Custom adapters to be appended to the wrapped package's `config.jsonc` after the `configContents` option.

          See the documentation for valid options:
          https://github.com/phiresky/ripgrep-all/wiki#custom-adapters

          Disjoint with the `configFile` option.
        '';
        mutatorType = types.listOf adapterStruct;
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
      '';
    };

    rg_flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be automatically appended to `ripgrep-all`'s invocation of `rg`.

        See the documentation of valid flags:
        https://manpages.ubuntu.com/manpages/jammy/man1/rg.1.html#:~:text=OPTIONS

        Disjoint with the `rg_configContents` option.
      '';
    };
    rg_configContents = {
      type = types.pathLike;
      description = ''
        `ripgreprc` file, containing flags to be automatically appended to `ripgrep-all`'s invocation of `rg`.

        See the documentation of valid flags:
        https://manpages.ubuntu.com/manpages/jammy/man1/rg.1.html#:~:text=OPTIONS

        This file should have each flag on its own line. See the documentation of the file's format:
        https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md#configuration-file

        Disjoint with the `rg_flags` options.
      '';
    };

    package = {
      type = types.derivation;
      description = "The ripgrep package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.ripgrep-all;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (builtins) toJSON;
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) optionals;
      flags = optionals (options ? flags) options.flags ++ optionals (options ? rgFlags) options.rg_flags;
      configContents = writeText "config.jsonc" (
        toJSON (
          (if options ? configContents then options.configContents else {})
          // (
            if options ? configAdapters then
              { custom_adapters = options.configAdapters; }
            else
              {}
          )
        )
      );
    in
    assert !(options ? flags && options ? configContents);
    assert !(options ? rg_flags && options ? rg_configContents);
    inputs.mkWrapper {
      inherit (options) package;
      inherit flags;
      name = "rga";
      symlinks = {
        "$out/ripgrep-all/config.jsonc" =
          if (options ? configContents || options ? configAdapters) then
            configContents
          else if options ? configFile then
            options.configFile
          else
            null;
      };

      environment = {
        XDG_CONFIG_HOME = "$out";
        RIPGREP_CONFIG_PATH = options.rg_configContents or null;
      };
    };
}
