{ types, ... } @ adios:
{
  name = "fish";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    # TODO: add mergeFunc for completions and functions options
    completions = {
      type = types.attrsOf types.string;
      description = ''
        Custom completions to be injected into the wrapped package.

        Each attribute should map the name of a command to inline fish script defining how the command should be completed.

        Disjoint with the `completionFiles` option.
      '';
    };
    completionsFiles = {
      type = types.listOf types.pathLike;
      description = ''
        Files containing custom completions to be injected into the wrapped package.

        Disjoint with the `completions` option.
      '';
      mutatorType = types.listOf types.pathLike;
      mergeFunc = adios.lib.merge.lists.concat;
    };

    functions = {
      type = types.attrsOf types.string;
      description = ''
        Custom functions to be injected into the wrapped package.

        Each attribute should map the name of a function to inline fish script defining its functionality.

        Disjoint with the `functionsFiles` option.
      '';
    };
    functionsFiles = {
      type = types.listOf types.pathLike;
      description = ''
        Files containing custom functions to be injected into the wrapped package.

        Disjoint with the `functions` option.
      '';
      mutatorType = types.listOf types.pathLike;
      mergeFunc = adios.lib.merge.lists.concat;
    };

    abbreviations = {
      type = types.string;
      description = ''
        Custom abbreviations to be injected into the wrapped package.

        When mutating this option, a special API is provided.
        In this API, each attribute maps an abbreviation to its expansion.
        The values can either be:
        - a normal string with no extra logic
        - a special struct, allowing abbrs to set the location of the cursor on expansion
        - a list, allowing abbrs to only expand when the commandline starts with a given command
        See the example for a demo.
      '';
      example = {
        s = "git status";
        c = "git commit";
        git = [
          { m = "merge"; }
          {
            rbi = {
              setCursor = true;
              expansion = "rebase -i HEAD~%";
            };
          }
        ];
      };
      mutatorType =
        let
          abbrWithCursor = types.struct "abbrWithCursor" {
            setCursor = types.bool;
            expansion = types.string;
          };
          # Just renamed for a nicer internal name
          abbrType = types.rename "abbr" (
            types.union [
              types.string
              (abbrWithCursor.override { unknown = false; })
            ]
          );
        in
        types.attrsOf (
          types.union [
            abbrType
            (types.listOf (types.attrsOf abbrType))
          ]
        );
      mergeFunc =
        { mutators, inputs }:
        let
          inherit (builtins) attrNames concatMap concatStringsSep isAttrs isString replaceStrings;

          abbrToString =
            abbr: expansion: setCursor: command:
            "abbr --add "
            + (if setCursor then "--set-cursor " else "")
            + (if command != null then "--command ${command} " else "")
            + "-- ${abbr} '${replaceStrings [ "'" ] [ "\\'" ] expansion}'";

          moduleToAbbrs =
            command: module:
            concatMap (
              abbr:
              let
                expansion = module.${abbr};
              in
              if isString expansion then
                [
                  (abbrToString abbr expansion false command)
                ]
              else if isAttrs expansion then
                [
                  (abbrToString abbr expansion.expansion expansion.setCursor command)
                ]
              else
                # Note that fish doesn't work with "nested" commands. You would
                # think `--command 'foo bar' -- b baz` would work. but it
                # doesn't. While technically the code could recurse twice here,
                # the type prevents it
                concatMap (moduleToAbbrs abbr) expansion
            ) (attrNames module);
        in
        concatStringsSep "\n" (concatMap (name: moduleToAbbrs null mutators.${name}) (attrNames mutators));
    };

    # TODO: add impure variant of this
    interactiveShellInit = {
      type = types.string;
      description = ''
        Shell initialization code to be automatically injected into the wrapped package.

        Only ran when Fish is initalized interactively.
      '';
      mutatorType = types.string;
      mergeFunc =
        { mutators, options }:
        let
          inherit (builtins) attrValues concatStringsSep;
        in
        concatStringsSep "\n" (
          [
            "status is-interactive || exit 0"
          ]
          ++ attrValues mutators
          ++ [ options.abbreviations ]
        );
    };

    package = {
      type = types.derivation;
      description = "The Fish package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.fish;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (builtins) listToAttrs attrNames;
    in
    assert !(options ? completions && options ? completionsFiles);
    assert !(options ? functions && options ? functionsFiles);
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = (
        if options ? interactiveShellInit then
          {
            "$out/share/fish/vendor_conf.d/config.fish" = writeText "config.fish" options.interactiveShellInit;
          }
        else
          {}
      )
      // (
        if options ? completionsFiles then
          listToAttrs (
            map (path: {
              name = "$out/share/fish/vendor_completions.d/${baseNameOf path}";
              value = path;
            }) options.completionsFiles
          )
        else if options ? completions then
          listToAttrs (
            map (path: {
              name = "$out/share/fish/vendor_completions.d/${path}.fish";
              value = writeText path options.completions.${path};
            }) (attrNames options.completions)
          )
        else
          {}
      )
      // (
        if options ? functionsFiles then
          listToAttrs (
            map (path: {
              name = "$out/share/fish/vendor_functions.d/${baseNameOf path}";
              value = path;
            }) options.functionsFiles
          )
        else if options ? functions then
          listToAttrs (
            map (path: {
              name = "$out/share/fish/vendor_functions.d/${path}.fish";
              value = writeText path options.functions.${path};
            }) (attrNames options.functions)
          )
        else
          {}
      );
    };
}
