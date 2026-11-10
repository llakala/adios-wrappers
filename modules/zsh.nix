{ types, merge, promise, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    zshrc = {
      type = types.string;
      description = ''
        zsh script to be injected into the wrapped package's `.zshrc`.
      '';
      example = ''
        # Enable vim mode
        bindkey -v

        # Enable completions. A custom zcompdump location must be used as the
        # default location will be $ZDOTDIR which is immutable.
        autoload -Uz compinit
        compinit -d ~/.cache/zsh/.zcompdump -C
      '';
    };
    extraZshrc = {
      type = types.string;
      description = ''
        zsh script to be injected after the `zshrcFiles` option in the wrapped
        package's `.zshrc`.
      '';
      example = ''
        # zoxide must be added at the end of the .zshrc so we use extraZshrc.
        # https://github.com/ajeetdsouza/zoxide?tab=readme-ov-file#installation
        eval "$(zoxide init zsh)"
      '';
    };

    zshrcFiles = {
      type = types.listOf types.pathLike;
      description = ''
        zsh files to be sourced after the `zshrc` option in the wrapped package's `.zshrc` file.
      '';
      merge = merge.lists.concat;
    };
    extraZshrcFiles = {
      type = types.listOf types.pathLike;
      description = ''
        zsh files to be sourced at the end of the wrapped package's `.zshrc` file.
      '';
      merge = merge.lists.concat;
    };

    settings = {
      type = types.attrsOf types.bool;
      description = ''
        Options to be enabled or disabled in the wrapped package's `.zshrc` file.

        See the [documentation](https://zsh.sourceforge.io/Doc/Release/Options.html) for valid options.
      '';
      example = {
        appendhistory = true;
        sharehistory = true;
        autocd = false;
        beep = false;
      };
      merge = merge.attrs.recursively;
    };

    variables = {
      type = types.attrs;
      description = ''
        Environment variables to be defined in the wrapped package's `.zshrc` file.
      '';
      example = {
        HISTFILE = "~/.histfile";
        HISTSIZE = 5000;
      };
      merge = merge.attrs.recursively;
    };

    aliases = {
      type = types.attrsOf (
        types.either types.string (
          types.struct "global alias" {
            global = types.bool;
            command = types.string;
          }
        )
      );
      description = ''
        Aliases to be defined in the wrapped package's `.zshrc` file. Aliases
        can either be a string defining the command to be aliased, or a struct
        where you can define the command and if the alias should be global.

        See the [documentation](https://zsh.sourceforge.io/Intro/intro_8.html) for valid options.
      '';
      example = {
        ls = "ls --color";
        G = {
          global = true;
          command = "| grep";
        };
      };
      merge = merge.attrs.recursively;
    };

    plugins = {
      type = types.listOf (
        types.either types.derivation (
          types.struct "plugin" {
            package = types.derivation;
            path = types.string;
          }
        )
      );
      description = ''
        Plugins to be appended to the wrapped package's `.zshrc`.

        If a value is a derivation, it will be sourced as
        `<derivation>/share/<derivation.pname>/<derivation.pname>.zsh` which
        should be compatible with the majority of plugins. If this path is
        incorrect then the value may be defined as an attrSet containing the
        attrs `package` and `path` and will be sourced as `<package>/<path>`.
      '';
      example = ''
        [
          pkgs.zsh-autosuggestions
          {
            package = pkgs.nix-zsh-completions;
            path = "share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh";
          }
        ];
      '';
      merge = merge.lists.concat;
    };

    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Runtime dependencies to be injected into the wrapped package's path.
      '';
      merge = merge.lists.concat;
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.zsh);
      description = "The zsh package to be wrapped.";
    };
  };

  inputs.mkWrapper.options = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) makeBinPath optionalString;
      inherit (builtins) concatStringsSep attrNames;
      # Apply some function to each element in the list, then concat all the
      # elements together with newlines in between
      mapAndConcat = func: elems: (concatStringsSep "\n" (map func elems)) + "\n";
      # Whether a .zshrc should be generated
      shouldConfigure =
        options ? zshrc
        || options ? zshrcFile
        || options ? plugins
        || options ? settings
        || options ? aliases
        || options ? variables;
      zshrc =
        let
          zshrcFiles = optionalString (options ? zshrcFiles) (
            mapAndConcat (file: "source ${file}") options.zshrcFiles
          );
          extraZshrcFiles = optionalString (options ? extraZshrcFiles) (
            mapAndConcat (file: "source ${file}") options.extraZshrcFiles
          );
          zshrcText = optionalString (options ? zshrc) "${options.zshrc}\n";
          extraZshrcText = optionalString (options ? extraZshrc) "${options.extraZshrc}\n";
          settings = optionalString (options ? settings) (
            mapAndConcat (name: if options.settings.${name} then "setopt ${name}" else "unsetopt ${name}") (
              attrNames options.settings
            )
          );
          variables = optionalString (options ? variables) (
            mapAndConcat (name: "${name}=${toString options.variables.${name}}") (attrNames options.variables)
          );
          aliases = optionalString (options ? aliases) (
            mapAndConcat (
              name:
              let
                value = options.aliases.${name};
              in
              if (value.global or false) then
                "alias -g ${name}='${value.command}'"
              else
                "alias ${name}='${value.command or value}'"
            ) (attrNames options.aliases)
          );
          plugins = optionalString (options ? plugins) (
            mapAndConcat (
              plugin:
              if plugin ? path then
                "source ${plugin.package}/${plugin.path}"
              else
                "source ${plugin}/share/${plugin.pname}/${plugin.pname}.zsh"
            ) options.plugins
          );
        in
        zshrcFiles
        + zshrcText
        + variables
        + aliases
        + settings
        + extraZshrcFiles
        + extraZshrcText
        + plugins;
    in {
      inherit (options) package;
      wrapperArgs =
        if options ? extraPackages then "--prefix PATH : ${makeBinPath options.extraPackages}" else null;
      symlinks = {
        "$out/.zshrc" = if shouldConfigure then writeText ".zshrc" zshrc else null;
      };
      environment = {
        ZDOTDIR = if shouldConfigure then "$out" else null;
      };
    }
  );

  result = promise ({ results }: results.mkWrapper);

  meta = {
    maintainers = [];
  };
}
