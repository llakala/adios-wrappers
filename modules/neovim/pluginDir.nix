{
  stdenvNoCC,
  envsubst,
  lib,
  ...
}:
{ package, startPlugins, optPlugins }:
let
  inherit (lib) attrNames attrValues getExe map;
in
stdenvNoCC.mkDerivation {
  name = "neovim-pluginDir";
  nativeBuildInputs = [ envsubst ];

  __structuredAttrs = true;
  preferLocalBuild = true;
  allowSubstitutes = true;

  sourcesArray = attrValues startPlugins ++ attrValues optPlugins;
  pathsArray =
    let
      fn = name: ps: map (p: "pack/plugins/${name}/" + p) (attrNames ps);
    in
    (fn "start" startPlugins) ++ (fn "opt" optPlugins);

  buildCommand = /* bash */ ''
    mkdir -p "$out/nix-support"
    for i in $(find -L "$out" -name 'propagated-build-inputs'); do
      cat "$i" >> "$out/nix-support/propagated-build-inputs"
    done
    source '${package.lua}/nix-support/utils.sh'
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

    ${getExe package} --headless -n -u NONE -i NONE \
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

    mkdir -p $out/pack/plugins
    for path in "$out/pack/plugins/"*/*
    do
      if [[ -d "$path" && -z "$(ls -A $path)" ]]; then
        rmdir $path
      fi
    done
  '';
}
