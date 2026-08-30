{ types, ... } @ adios:
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
      mergeFunc = adios.lib.merge.lists.concat;
    };
    extraZshrcFiles = {
      type = types.listOf types.pathLike;
      description = ''
        zsh files to be sourced at the end of the wrapped package's `.zshrc` file.
      '';
      mergeFunc = adios.lib.merge.lists.concat;
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
      mergeFunc = adios.lib.merge.attrs.recursively;
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
      mergeFunc = adios.lib.merge.attrs.recursively;
    };

    aliases = {
      type = types.attrsOf (
        types.union [
          types.string
          (types.struct "global alias" {
            global = types.bool;
            command = types.string;
          })
        ]
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
      mergeFunc = adios.lib.merge.attrs.recursively;
    };

    plugins = {
      type = types.listOf (
        types.union [
          types.derivation
          (types.struct "plugin" {
            package = types.derivation;
            path = types.string;
          })
        ]
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
      mergeFunc = adios.lib.merge.lists.concat;
    };

    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Runtime dependencies to be injected into the wrapped package's path.
      '';
      mergeFunc = adios.lib.merge.lists.concat;
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.zsh;
      description = "The zsh package to be wrapped.";
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (inputs.nixpkgs.lib) makeBinPath;
      inherit (builtins) concatStringsSep attrNames;
      optionals = cond: list: if cond then list else [];
      optional =
        cond: elem:
        if cond then
          [ elem ]
        else
          [];
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
          zshrcFiles = optionals (options ? zshrcFiles) (map (file: "source ${file}") options.zshrcFiles);
          extraZshrcFiles = optionals (options ? extraZshrcFiles) (
            map (file: "source ${file}") options.extraZshrcFiles
          );
          zshrcText = optional (options ? zshrc) options.zshrc;
          extraZshrcText = optional (options ? extraZshrc) options.extraZshrc;
          settings = optionals (options ? settings) (
            map (name: if options.settings.${name} then "setopt ${name}" else "unsetopt ${name}") (
              attrNames options.settings
            )
          );
          variables = optionals (options ? variables) (
            map (name: "${name}=${toString options.variables.${name}}") (attrNames options.variables)
          );
          aliases = optionals (options ? aliases) (
            map (
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
          plugins = optionals (options ? plugins) (
            map (
              plugin:
              if plugin ? path then
                "source ${plugin.package}/${plugin.path}"
              else
                "source ${plugin}/share/${plugin.pname}/${plugin.pname}.zsh"
            ) options.plugins
          );
        in
        concatStringsSep "\n" (
          zshrcFiles
          ++ zshrcText
          ++ variables
          ++ aliases
          ++ settings
          ++ extraZshrcFiles
          ++ extraZshrcText
          ++ plugins
        );
    in
    inputs.mkWrapper {
      inherit (options) package;
      wrapperArgs =
        if options ? extraPackages then "--prefix PATH : ${makeBinPath options.extraPackages}" else null;
      symlinks = {
        "$out/.zshrc" = if shouldConfigure then writeText ".zshrc" zshrc else null;
      };
      environment = {
        ZDOTDIR = if shouldConfigure then "$out" else null;
      };
    };

  meta = {
    maintainers = [ "poacher" ];
  };
}
