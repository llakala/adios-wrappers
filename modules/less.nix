{ types, ... }:
{
  name = "less";

  inputs = {
    mkWrapper.path = "/mkWrapper";
    nixpkgs.path = "/nixpkgs";
  };

  options = {
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be automatically appended when running less.

        See the documentation for valid options:
        https://man7.org/linux/man-pages/man1/less.1.html#:~:text=OPTIONS,-top

        Disjoint with the `configFile` option.
      '';
    };

    # TODO: add rfc42 variants of the #command and #line-edit sections
    configFile = {
      type = types.pathLike;
      description = ''
        `lesskey` file to be injected into the wrapped package.

        This file doesn't just contain keybinds, but can also set flags with the
        `#env` section.

        See the documentation for valid options:
        https://man7.org/linux/man-pages/man1/lesskey.1.html

        Disjoint with the `flags` option.
      '';
    };

    package = {
      type = types.derivation;
      description = "The less package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.less;
    };
  };

  impl =
    { options, inputs }:
    let
      inherit (builtins) concatStringsSep;
    in
    assert !(options ? flags && options ? configFile);
    inputs.mkWrapper {
      inherit (options) package;
      environment = {
        LESS = if options ? flags then concatStringsSep " " options.flags else null;
        LESSKEYIN = options.configFile or null;
      };
    };
}
