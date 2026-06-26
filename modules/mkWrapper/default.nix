{ types, ... }:
let
  nullOrString = types.nullOr types.string;
in {
  inputs = {
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    package = {
      type = types.derivation;
      description = "The package to be wrapped.";
    };
    name = {
      type = types.string;
      defaultFunc = { options }: options.package.pname;
      description = ''
        The name of the package to be wrapped.

        This determines the pname of the wrapped package.
      '';
    };
    extraPaths = {
      type = types.listOf types.derivation;
      description = "Extra derivations which should have their directory structures replicated in the final package.";
      default = [];
    };
    binaryName = {
      type = types.string;
      description = ''
        The name of the binary to be wrapped.

        This sets the `meta.mainProgram` of the wrapped package, and the default `binaryPath` to wrap with.
      '';
      defaultFunc = { options }: options.package.meta.mainProgram or options.name;
    };
    binaryPath = {
      type = types.string;
      defaultFunc = { options }: "$out/bin/${options.binaryName}";
      description = ''
        The path of the binary within the input derivation to be wrapped.

        This should only be set if the binary isn't inside $out/bin. If it is, `binaryName` can be used instead.
      '';
    };
    preWrap = {
      type = nullOrString;
      description = "Commands to be run before the wrapping process in the build steps.";
      default = null;
    };
    postWrap = {
      type = nullOrString;
      description = "Commands to be run after the wrapping process in the build steps.";
      default = null;
    };
    wrapperArgs = {
      type = nullOrString;
      description = "Extra args passed directly to wrapProgram.";
      default = null;
    };
    environment = {
      type = types.attrsOf (
        types.union [
          types.null
          types.pathLike
          (types.struct "readFromFileAtRuntime" {
            readFromFile = types.bool;
            value = types.pathLike;
          })
        ]
      );
      description = "Environment variables to be set during the execution of the wrapped program.";
      default = {};
    };
    symlinks = {
      type = types.attrsOf (types.nullOr types.pathLike);
      description = ''
        Symlinks to be included in the resulting derivation.
        Each key specifies the location within the derivation to create the symlink.
        Each value specifies where the symlink should be directed to.
      '';
      default = {};
    };
    flags = {
      type = types.listOf types.string;
      description = "Flags to be automatically appended to the wrapped program.";
      default = [];
    };
  };

  impl =
    let
      inherit (builtins) attrNames concatMap concatStringsSep;
      ifNotNull = x: if x != null then x else "";
      passAsFile = [
        "buildCommand"
        "paths"
      ];
    in
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) stdenvNoCC callPackage lndir;
      makeBinaryWrapper = callPackage ./makeBinaryWrapper/package.nix {};
      environmentStr = concatStringsSep " " (
        concatMap (
          var:
          let
            value = options.environment.${var};
          in
          if value == null then
            []
          else if (value.readFromFile or false) then
            [ "--set-from-file ${var} \"${value.value}\"" ]
          else
            [ "--set ${var} \"${value}\"" ]
        ) (attrNames options.environment)
      );
      symlinkedStr = concatStringsSep "\n" (
        concatMap (
          symlink:
          let
            destination = options.symlinks.${symlink};
          in
          if destination == null then
            []
          else
            [
              "mkdir -p $(dirname ${symlink})"
              "ln -s ${destination} ${symlink}"
            ]
        ) (attrNames options.symlinks)
      );
      flagsStr = concatStringsSep " " (map (flag: "--add-flag \"${flag}\"") options.flags);
    in
    stdenvNoCC.mkDerivation {
      name = "${options.name}-wrapped";
      buildInputs = [ makeBinaryWrapper ];
      paths =
        if options.extraPaths == [] then
          [ "${options.package}" ]
        else
          map (path: "${path}") ([ options.package ] ++ options.extraPaths);
      meta.mainProgram = options.binaryName;
      passthru = options.package.passthru or {};

      preferLocalBuild = true;
      allowSubstitutes = false;
      enableParallelBuilding = true;
      inherit passAsFile;

      buildCommand = ''
        mkdir -p $out
        for i in $(cat $pathsPath); do
          ${lndir}/bin/lndir -silent $i $out
        done
        ${symlinkedStr}
        ${ifNotNull options.preWrap}
        ${
          if environmentStr == "" && options.wrapperArgs == "" && options.flags == [] then
            ""
          else
            ''
              wrapProgram ${options.binaryPath} ${environmentStr} ${flagsStr} ${ifNotNull options.wrapperArgs}
            ''
        }
        ${ifNotNull options.postWrap}
      '';
    };
}
