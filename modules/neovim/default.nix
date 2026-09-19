# thank you to Gerg-L for his work on mnw, as most of the bash is copied from there.
{ types, ... }:
{
  inputs = {
    nixpkgs.from = { parent }: parent.nixpkgs;
    mkWrapper.from = { parent }: parent.mkWrapper;
  };

  options = {
    initLuaFile = {
      type = types.pathLike;
      description = ''
        `init.lua` file to be run on startup.

        Disjoint with the initLuaContents option.
      '';
      example = "./init.lua";
    };
    initLuaContents = {
      type = types.string;
      description = ''
        The contents of the `init.lua` file to be run on startup.

        Disjoint with the initLuaFile option.
      '';
      example = ''
        require("keybinds")
        require("plugins")
        require("options")
      '';
    };
    aliases = {
      type = types.listOf types.string;
      description = ''
        Additional program names to launch `nvim` under.
      '';
      example = [
        "vi"
        "vim"
      ];
    };
    extraPackages = {
      type = types.listOf types.derivation;
      description = "A list of extra packages to be included in neovim's $PATH";
      example = ''
        with inputs.nixpkgs; [
          pkgs.lua-language-server
          pkgs.stylua
          pkgs.nixfmt
        ]
      '';
    };
    extraLuaPackages = {
      type = types.function;
      description = ''
        A function returning a list of extra packages to be included in lua's $PATH.
      '';
      example = ''
        ps: [ ps.jsregexp ]
      '';
      default = _: [];
    };
    startPlugins = {
      type = types.attrsOf types.derivation;
      description = ''
        An attrset of neovim *plugins* which are loaded on startup.
      '';
      example = ''
        {
          inherit (vimPlugins) fzf-lua nvim-surround;
          custom-plugin = callPackage ./custom-plugin.nix {};
        }
      '';
    };
    optPlugins = {
      type = types.attrsOf types.derivation;
      description = ''
        A attrset of nvim plugins that are only loaded when `packadd` is called.

        This follows the same ruleset as startPlugins.
      '';
    };
    devPlugins = {
      type = types.listOf (types.either types.path types.string);
      description = ''
        A list of *plugin* paths, which will be included in Neovim's 'runtimepath'.

        Your personal config should be declared as a plugin here, and then loaded
        via the 'initLuaFile'/'initLuaContents' option:

        Plugins that are set to strings will be treated as absolute paths
        and loaded impurely at runtime, rather than at buildtime. This allows
        for "hot reloading", which is helpful inside a devshell.

        A plugin's structure is described [here](https://neovim.io/doc/user/pack/#package-create).
      '';
      example = ''
        [
          # loading your personal config without hot reloading
          ./nvim
          # alternatively, setting up hot reloading inside a flake
          "/home/your-username/Projects/nixos-config/wrappers/neovim/nvim"
          # and if you don't use flakes, this works:
          (toString ./nvim)
        ]
      '';
    };
    treesitterPackage = {
      type = types.derivation;
      description = ''
        The nvim-treesitter package to be used.

        This should also include the grammars as dependencies, which can be done via either
        `nvim-treesitter.withAllGrammars` or `nvim-treesitter.withPlugins (p: [ p.foo p.bar ])`.
      '';
      example = "pkgs.vimPlugins.nvim-treesitter.withAllGrammars";
    };
    package = {
      type = types.derivation;
      description = "The neovim package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.neovim-unwrapped;
    };
  };

  impl =
    { inputs, options }:
    let
      inherit (builtins)
        attrValues
        catAttrs
        concatLists
        concatMap
        concatStringsSep
        listToAttrs
        replaceStrings
        ;
      inherit (inputs.nixpkgs.pkgs) symlinkJoin writeText;
      inherit (inputs.nixpkgs.lib) getName makeBinPath optionalAttrs optionals removePrefix;
      toLua = inputs.nixpkgs.lib.generators.toLua {};

      getDependencies =
        let
          removeVimPluginPrefix = removePrefix "vimplugin-";
          replaceDot = replaceStrings [ "." ] [ "-" ];
          recurse = concatMap (
            p:
            optionals (p != null) [
              {
                # vimplugin-lualine.nvim -> lualine-nvim
                # we turn dots into dashes for consistency with the attrset
                # form. this will affect :packadd and lazy loaders, so be sure
                # to use dashes instead of dots!
                name = replaceDot (removeVimPluginPrefix (getName p));
                value = p;
              }
            ]
            ++ optionals (p ? dependencies) (recurse p.dependencies)
          );
        in
        pluginAttrs: listToAttrs (recurse (concatLists (catAttrs "dependencies" (attrValues pluginAttrs))));

      # we do a simple merge here, where start plugins take precedence over
      # discovered dependencies
      transformedStartPlugins =
        (getDependencies (options.startPlugins or {}))
        # deps of opt plugins are loaded as start plugins - preserves mnw compat
        // (getDependencies (options.optPlugins or {}))
        // (options.startPlugins or {})
        // optionalAttrs (options ? treesitterPackage) {
          nvim-treesitter = options.treesitterPackage;
          nvim-treesitter-grammars = symlinkJoin {
            name = "nvim-treesitter-grammars";
            paths = attrValues (getDependencies {
              nvim-treesitter = options.treesitterPackage;
            });
          };
        };

      pluginDir = import ./pluginDir.nix inputs.nixpkgs.pkgs {
        inherit (options) package;
        startPlugins = transformedStartPlugins;
        optPlugins = options.optPlugins or {};
      };

      generatedInitLua =
        let
          luaEnv = options.package.lua.withPackages options.extraLuaPackages;
          inherit (options.package.lua.pkgs) luaLib;
          userInitLua =
            if options ? initLuaFile then "dofile('${options.initLuaFile}')" else options.initLuaContents;
          # we don't prepend/append to the defaults, since they load a bunch of
          # impure state from xdg
          packpath = toLua [
            pluginDir
            "${options.package}/share/nvim/runtime"
          ];
          runtimepath = toLua (
            [ pluginDir ]
            ++ (options.devPlugins or [])
            ++ [
              "${options.package}/share/nvim/runtime"
              "${options.package}/lib/nvim"
            ]
            ++ map (p: p + "/after") (options.devPlugins or [])
          );
        in
        writeText "init.lua" /* lua */ ''
          vim.env.PATH = vim.env.PATH .. ":${makeBinPath (options.extraPackages or [])}"
          package.path = "${luaLib.genLuaPathAbsStr luaEnv};$LUA_PATH" .. package.path
          package.cpath = "${luaLib.genLuaCPathAbsStr luaEnv};$LUA_CPATH" .. package.cpath
          vim.opt.packpath = ${packpath}
          vim.opt.runtimepath = ${runtimepath}

          ${userInitLua}
        '';
    in
    assert options ? initLuaFile != options ? initLuaContents;
    inputs.mkWrapper {
      pname = "neovim";
      binaryName = "nvim";
      package = options.package // {
        passthru = options.package.passthru // {
          inherit pluginDir;
          config = options // {
            startPlugins = transformedStartPlugins;
          };
        };
      };
      environment.VIMINIT = "source $out/share/nvim/init.lua";
      symlinks = {
        "$out/share/nvim/init.lua" = generatedInitLua;
        "$out/share/nvim/plugins" = "${pluginDir}/pack/plugins";
      };
      postWrap = concatStringsSep "\n" (
        map (x: ''ln -s "$out/bin/nvim" "$out/bin/${x}"'') (options.aliases or [])
      );
    };

  meta = {
    maintainers = [
      "llakala"
      "Squawkykaka"
    ];
  };
}
