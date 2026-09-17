{ types, ... }: {
  # thank you to Gerg-L, for his work on mnw as most of the bash is copied from there.
  inputs = {
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    # this probably needs to be in the store? maybe a custom type utilizing
    # lib.isStorePath
    initLuaFile = {
      type = types.pathLike;
      description = ''
        `init.lua` file to be ran on startup.

        Disjoint with the initLuaContents option.
      '';
      example = ''
        (pkgs.writeText "init.lua" '''
           print('hello world')
         ''')
      '';
    };
    initLuaContents = {
      type = types.string;
      description = ''
        The contents of the `init.lua` file to be ran on startup.

        Disjoint with the initLuaFile option.
      '';
      example = ''
        require("myConfig")
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
          pkgs.rg
          pkgs.fzf
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
      type = types.attrsOf types.pathLike;
      description = ''
        An attrset of neovim *plugins* which are loaded on startup.

        Your personal config should be declared as a plugin here, and then loaded
        via the 'initLuaFile'/'initLuaContents' option:

        ```lua
        -- this loads nvim/lua/init.lua
        require("init")
        ```

        Plugins that are set to strings will be treated as absolute paths
        and loaded impurely at runtime, rather than at buildtime. This allows
        for "hot reloading", which is helpful inside a devshell.

        A plugin's structure is described [here](https://neovim.io/doc/user/pack/#package-create).
      '';
      example = ''
        {
          inherit (pkgs.vimPlugins) fzf-lua nvim-surround;
          custom-plugin = pkgs.callPackage ./startPlugins/foo.nix {};

          # loading your personal config without hot reloading
          myconfig = ./nvim;
          # alternatively, setting up hot reloading inside a flake
          myconfig = "/home/your-username/Projects/nixos-config/wrappers/neovim/nvim";
          # and if you don't use flakes, this works too:
          myconfig = toString ./nvim;
        }
      '';
    };
    # TODO: support hot reloading here too? is it even possible to do that?
    optPlugins = {
      type = types.attrsOf (types.either types.path types.derivation);
      description = ''
        A attrset of nvim plugins that are only loaded when `packadd` is called.

        This follows the same ruleset as startPlugins, but doesn't support impure paths.
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
        baseNameOf
        concatStringsSep
        foldl'
        hashString
        isAttrs
        isString
        substring
        ;
      inherit (inputs.nixpkgs.pkgs)
        envsubst
        lndir
        # TODO: use makeBinaryWrapper?
        makeShellWrapper
        stdenvNoCC
        symlinkJoin
        writeText
        ;
      inherit (inputs.nixpkgs.lib)
        escapeShellArgs
        filterAttrs
        getExe
        getName
        getVersion
        makeBinPath
        mapAttrsToList
        removePrefix
        ;

      transformPlugins =
        let
          recurse =
            parent: isDep:
            foldl'
              (
                acc: e:
                let
                  name = removePrefix "vimplugin-" (
                    if isAttrs e then getName e else "${baseNameOf e}-${substring 0 7 (hashString "md5" "${e}")}"
                  );

                  item.${name} = e;
                in {
                  deps = (
                    if isDep then
                      acc.deps // item
                    else
                      acc.deps
                  )
                  // (
                    if e ? dependencies then
                      (recurse name true e.dependencies).deps
                    else
                      {}
                  );
                  notDeps =
                    if isDep then
                      acc.notDeps
                    else
                      acc.notDeps // item;
                }
              )
              {
                deps = {};
                notDeps = {};
              };

        in
        recurse "" false;

      # TODO: this needs fixing, we're currently not using the benefits of the
      # attrset form at all if we just take attrValues. whole idea is that the
      # names are determined by the attribute names instead, we need to decide
      # if that's valuable
      transformedOpt = transformPlugins (attrValues (options.optPlugins or {}));
      transformedStart = transformPlugins (attrValues (options.startPlugins or {}));
      transformedTreesitter = transformPlugins [ options.treesitterPackage ];

      startAttrs = transformedOpt.deps // transformedStart.deps // transformedStart.notDeps;

      optPlugins = transformedOpt.notDeps;

      startPlugins = (filterAttrs (_: v: v != null && !isString v) startAttrs) // (
        if options ? treesitterPackage then
          {
            nvim-treesitter-grammars = symlinkJoin {
              name = "nvim-treesitter-grammars";
              paths = attrValues transformedTreesitter.deps;
            };
          }
          // transformedTreesitter.notDeps
        else
          {}
      );
      devPlugins = filterAttrs (_: isString) startAttrs;

      generatedInitLua =
        let
          luaEnv = options.package.lua.withPackages options.extraLuaPackages;
          inherit (options.package.lua.pkgs) luaLib;

          sourceLua =
            if options ? initLuaFile then "dofile('${options.initLuaFile}')" else options.initLuaContents;
        in
        writeText "init.lua" /* lua */ ''
          -- cannot be adios-wrappers, lua does not support `-` inside variables
          adioswrappers = { configDir = "$out" }
          vim.env.PATH = vim.env.PATH .. ":${makeBinPath (options.extraPackages or [])}"
          package.path = "${luaLib.genLuaPathAbsStr luaEnv};$LUA_PATH" .. package.path
          package.cpath = "${luaLib.genLuaCPathAbsStr luaEnv};$LUA_CPATH" .. package.cpath

          ${sourceLua}
        '';

      # TODO: maybe move this to another file, so wrapper is under
      # neovim/default.nix
      configDir = stdenvNoCC.mkDerivation {
        name = "neovim-configDir";
        nativeBuildInputs = [ envsubst ];
        __structuredAttrs = true;
        preferLocalBuild = true;

        sourcesArray =
          (mapAttrsToList (_: v: "${v}") startPlugins) ++ (mapAttrsToList (_: v: "${v}") optPlugins);
        pathsArray =
          let
            fn = name: mapAttrsToList (n: _: "pack/adios/${name}/" + n);
          in
          (fn "start" startPlugins) ++ (fn "opt" optPlugins);

        buildCommand = /* bash */ ''
          mkdir -p "$out/nix-support"
          for i in $(find -L "$out" -name 'propagated-build-inputs'); do
            cat "$i" >> "$out/nix-support/propagated-build-inputs"
          done
          source '${options.package.lua}/nix-support/utils.sh'
          if declare -f -F "_addToLuaPath" > /dev/null; then
            _addToLuaPath "$out"
          fi

          if [[ "$LUA_PATH" == ";;" ]]; then
            export LUA_PATH=""
          else
            export LUA_PATH="''${LUA_PATH:-}"
          fi
          if [[ "$LUA_CPATH" == ";;" ]]; then
            export LUA_CPATH=""
          else
            export LUA_CPATH="''${LUA_CPATH:-}"
          fi
          envsubst < '${generatedInitLua}' > "$out/init.lua"

          tmpScript="$(mktemp)"

          for ((i = 0; i < "''${#pathsArray[@]}"; i++ ))
          do
            path="''${pathsArray["$i"]}"
            source="''${sourcesArray["$i"]}"
            if [[ -e "$source/doc" && ! -e "$source/doc/tags" ]]; then
              mkdir -p "$out/$path/doc"
              ln -ns "$source/doc/"* -t "$out/$path/doc"
              echo "packadd $(basename "$path")" >> "$tmpScript"
            fi
          done

          ${getExe options.package} --headless -n -u NONE -i NONE \
            -c "set packpath=$out" \
            -c "source $tmpScript" \
            -c "helptags ALL" \
            "+quit!"

          shopt -s extglob
          for ((i = 0; i < "''${#pathsArray[@]}"; i++ ))
          do
            path="''${pathsArray["$i"]}"
            source="''${sourcesArray["$i"]}"

            mkdir -p "$out/$path"

            tolink=("$source/"!(doc))

            if (( ''${#tolink} )); then
              ln -ns "''${tolink[@]}"  -t "$out/$path"
            fi

            if [[ -e "$source/doc" && ! -e "$out/$path/doc" ]]; then
              ln -ns "$source/doc" -t "$out/$path"
            fi
          done
          shopt -u extglob

          for path in "$out/pack/adios/"*/*
          do
            if [[ -d "$path" && -z "$(ls -A $path)" ]]; then
              rmdir $path
            fi
          done
        '';
      };

      wrapperArgsStr = escapeShellArgs [
        "--add-flags"
        "--cmd \"lua vim.opt.packpath:prepend('${configDir}'); vim.opt.runtimepath:prepend('${configDir}'); ${
          if devPlugins != {} then
            ''
              vim.opt.runtimepath:prepend('${
                concatStringsSep "," (attrValues devPlugins)
              }'); vim.opt.runtimepath:append('${
                concatStringsSep "," (map (p: p + "/after") (attrValues devPlugins))
              }')
            ''
          else
            ""
        }\""
        "--set"
        "VIMINIT"
        "source ${configDir}/init.lua"
      ];
    in
    assert options ? initLuaFile != options ? initLuaContents;
    stdenvNoCC.mkDerivation {
      pname = "neovim";
      version = getVersion options.package;

      dontUnpack = true;
      preferLocalBuild = true;
      strictDeps = true;
      allowSubstitutes = false;
      enableParallelBuilding = true;

      dontFixup = true;

      nativeBuildInputs = [
        makeShellWrapper
        lndir
      ];

      installPhase = ''
        runHook preInstall

        mkdir -p $out
        lndir -silent '${options.package}' "$out"

        wrapProgramShell "$out/bin/nvim" ${wrapperArgsStr}

        ${concatStringsSep "\n" (
          map (x: ''ln -s "$out/bin/nvim" "$out/bin/"'${x}' '') options.aliases or []
        )}

        runHook postInstall
      '';

      passthru = {
        inherit configDir;
        config = options;
      };

      meta = {
        inherit (options.package.meta) mainProgram;
      };
    };

  meta = {
    maintainers = [ "Squawkykaka" ];
  };
}
