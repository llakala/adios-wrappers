Thank you for wanting to contribute to the project!

More modules and options are always welcome. However, they're expected to follow some style guides.

## RFC42 and impure options

Each option should aim to have an RFC42 variant and an impure path variant.

An RFC42 option is what you're familiar with from nixos or home-manager, where the attribute set is automatically
transformed into the correct language.

An impure path variant may be less familiar to you. All the wrappers in adios-wrappers aim to support an impure mode. If
the user runs toString on a config file they've provided (ex: `configFile = toString ./gitconfig;`), then the path won't
be copied to the nix store, and will instead be turned into a string which is read from at runtime. This means the user
can run their program and have it always use the newest version.

Any new configuration options should be added with both variants, with checks that the options aren't both set at once.
Here's an example module that adds both:

```nix
{ types, ... }:
{
  inputs = {
    nixpkgs.from = { parent }: parent.nixpkgs;
    mkWrapper.from = { parent }: parent.mkWrapper;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `foo.toml`.

        See the documentation for valid options:
        https://fake.website.com

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `foo.toml` file to be injected into the wrapped package.

        See the documentation for valid options:
        https://fake.website.com

        Disjoint with the `settings` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.foo;
      description = "The foo package to be wrapped.";
    };
  };
  impl =
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.toml {};
    in
    assert !(options ? settings && options ? configFile);
    inputs.mkWrapper {
      symlinks = {
        "$out/foo/foo.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "$out/foo/foo.toml" options.settings
          else
            null;
      };
      environment = {
        FOO_CONFIG_FILE = "$out/foo/foo.toml";
      };
    };
}
```

## Choosing where to source your generators

There are lots of ways to turn a `settings` option into a file that can be used in `symlinks`. However, where possible,
we prefer to source from `pkgs.formats`. Formats automatically create a file for you, so the wrappers don't have to call
`writeTextFile` themselves. Formats are also the standard for repos like nixpkgs and home-manager. If you have the
choice between using something from `builtins`, `lib.generators`, or `pkgs.formats`, please choose formats!

## Description guidelines

All newly introduced options should come with descriptions. These descriptions should follow the established format
that's been used in the other modules. To ease this experience, a template is provided for the most common types of
option.

### `settings`

```nix
description = ''
  Settings to be injected into the wrapped package's `$FILE_NAME`.

  See the documentation for $DOCS_REASON:
  $DOCS_LINK_HERE

  Disjoint with the `configDir` option.
'';
```

The documentation section is optional if there's not a good link, but trying to find one would be nice.

### `configFile`

```nix
description = ''
  `$FILE_NAME` file to be injected into the wrapped package.

  See the documentation for $DOCS_REASON:
  $DOCS_LINK_HERE

  Disjoint with the `settings` option.
'';
```

### `flags`

```nix
description = ''
  Flags to be automatically appended when running $PROGRAM_NAME.

  See the documentation for $DOCS_REASON:
  $DOCS_LINK_HERE

  Disjoint with the `$DISJOINT_OPTION` option.
'';
```

### `package`

```nix
description = "The $program_name package to be wrapped.";
```

## Option naming conventions

We try to use a common spec for naming options. A list is provided here of common option purposes and what the option
should be named.

### Common option names

`package`: Sets the derivation to be wrapped by the module. Required for all modules (except in special cases).

`settings`: An attrset representing the primary config file. Used when a file format has a canonical representation in
Nix (think JSON, TOML, YAML, etc). Typically disjoint with a `configFile` option.

`configContents`: The contents of the primary config file. Used when a file format can't be canonically represented in
Nix (think shell scripts, KDL, and turing-complete languages). Typically disjoint with a `configFile` option.

`configFile`: Path of the primary config file, symlinked directly into the wrapper. Typically disjoint with a `settings`
or `configContents` option.

`flags`: A list of flags to be passed to the program, if it's primarily configured via flags instead of a config file
(think of something like ripgrep). _Sometimes_ disjoint with a `configFile` option if the program also supports reading
from a config file.

`keybinds`: An attrset representing custom keybinds. Typically disjoint with a `keybindsFile` option.

`keybindsFile`: Path of the custom keybinds file, symlinked directly into the wrapper. Typically disjoint with a
`keybinds` option.

`theme`: An attrset representing a custom theme. Named "theme" instead of "themes" if the program only supports a
single custom theme. Typically disjoint with a `themeFile` option.

`themes`: An attribute set representing multiple custom themes. Named "themes" instead of "theme" if the program supports
defining multiple themes. Typically disjoint with a `themeFiles` option.

`themeFile`: Path of the custom theme file, symlinked directly into the wrapper. Typically disjoint with a `theme`
option.

`themeFiles`: Attribute set of paths, each containing a custom theme file to be symlinked directly into the wrapper.
Typically disjoint with a `themes` option.

### If your option doesn't look like one of these

Try to match the _vibes_ of this list, if your usecase isn't listed. A `modules` option should likely come along with a
`moduleFiles` option, for example.

### Whitespace

When defining the `options` attrset, disjoint options should be next to each other, with the RFC42 option first, There
should then be newlines between each "set" of options (so between `settings` / `configFile` and `keybinds` /
`keybindsFile`.

## Docs generation

Documentation is generated by `dev/generate-docs.sh` and produces an `options.json` file that contains docs on all
modules.

When PRing changes that modify the options of a module, regenerate the `options.json` file by doing the following:

```
dev/generate-docs.sh > docs/options.json
```

This will be checked in CI.

## Formatting

A fork of `nixfmt` is used for formatting modules (and other .nix files).

When PRing changes that modify these files, enter the devshell with:
```sh
direnv allow # if you have direnv installed (recommended)
nix-shell dev/shell.nix # if you don't have direnv installed
```
and format changed files with:
```sh
nixfmt filename # in-editor formatting is recommended for UX
```

This will be checked in CI.
