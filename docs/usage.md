Once you've copied the flake/npins example, it's time to start defining some wrappers. To do this, we'll use a strategy
known as _injections_.

To understand this, we should first understand how Adios modules can be called directly.

# How Adios modules are called

Given an Adios module defined as such:

```nix
# modules/demo.nix
{ types, ... }:
{
  options = {
    num1 = {
      type = types.int;
      default = 10;
    };
    num2 = {
      type = types.int;
      default = 5;
    };
  };

  impl = { options }: options.num1 + options.num2;
}
```

This module is now a function. If we call it with `modules.demo {}`, we get `15` as the output - since `num1` and `num2`
fall back to their default values. But if we instead call it with `modules.demo { num1 = 1; num2 = 2; }`, we get `3`. In
this regard, Adios modules are like fancy functions.

We _could_ call our wrappers in the same way:

```nix
wrappers.git {
  settings = {
    core.email = "my.email@here.com";
  };
}
```

But this is limiting for multiple reasons. Calling a module's `impl` directly only allows specifying constant values for
each option. What if you wanted to:

1. Set an option's value conditionally based on the value of another option
2. Add a new input to a module, or change an existing input to point somewhere else
3. Set the mutators for an option (only possible within the module's definition)
4. Set config for some module `foo` "globally", so another module `bar` that depends on `foo` would be able to view your
   changes

To accomplish these things, we can _inject_ our config into the module definitions themselves.

# What is `lib.recursiveUpdate`?

`lib.recursiveUpdate` can be thought of as "recursive `//`". Here's an example of how it works:

```nix
let
  inherit (pkgs) lib;

  base = {
    nested = {
      a = 1;
      b = 2;
    };
  };

  injections = {
    nested = {
      a = 7;
      c = 25;
    };
  }

  final = lib.recursiveUpdate base injections;
in
# returns true
final == {
  nested = {
    a = 7;
    b = 2;
    c = 25;
  };
}
```

As you can see, the injections are able to "update" the left attrset, with the right attrset taking priority on a key
collision. This combines well with a property of Adios modules - they can be accessed as attrsets without any
knowledge of their final args. Here's an example of how `recursiveUpdate` can be used to modify an Adios module:

```nix
{ adios }:
let
  inherit (adios) types;

  module = {
    options = {
      age = {
        type = types.int;
        default = 10;
      };
      age-someday = {
        type = types.int;
        defaultFunc = { options }: options.age + 1;
      };
    };

    impl = { options }: ''
      You are ${toString options.age} years old.
      Someday, you will be ${toString options.age-someday} years old.
    '';
  };


  injections = {
    options = {
      age.default = 35;
      age-someday.type = types.float;
      age-someday.defaultFunc = { options }: options.age + 0.1;
    };
  };

  final = lib.recursiveUpdate module injections;
in
# returns true
(final {}) == ''
  You are 35 years old.
  Someday, you will be 35.1 years old.
''
```

We can now use `recursiveUpdate` to inject virtually anything into the `adios-wrapeprs` module definitions. There's only
one more step to go before we're able to start defining wrappers.

# What is `adios.lib.importModules`?

With what we already know, we could define all our injections within `wrappers.nix` like this:
```nix
let
  injections = {
    less = {
      options.flags.default = [ "--quit-if-one-screen" ];
    };
    git = {
      inputs.less.from = { parent }: parent.less;
      options.settings.defaultFunc =
        { options, inputs }:
        {
          core.pager = inputs.nixpkgs.lib.getExe (options { });
        };
      mutations."/fish".abbreviations = _: {
        gs = "git status";
      };
    };
    fish = {
      options.abbreviations.mutators = [ "/git" ];
    };
  };

  root = {
    modules = lib.recursiveUpdate adios-wrappers injections;
  };
```

But this balloons out of control as the number of modules grows. Instead, we can use `adios.lib.importModules`, which
will automatically import a set of modules in a directory.

```nix
let
  # ...

  root = {
    modules = lib.recursiveUpdate adios-wrappers (adios.lib.importModules ./wrappers);
  };
```

Then, each of the injections can be moved into its own file under `./wrappers`:

```nix
# wrappers/less.nix
_:
{
  options.flags.default = [ "--quit-if-one-screen" ];
}
```

```nix
# wrappers/git.nix
_:
{
  inputs.less.from = { parent }: parent.less;

  options.settings.defaultFunc =
    { options, inputs }:
    {
      core.pager = inputs.nixpkgs.lib.getExe (options { });
    };

  mutations."/fish".abbreviations = _: {
    gs = "git status";
  };
}
```

```nix
# wrappers/fish.nix
_:
{
  options.abbreviations.mutators = [ "/git" ];
}
```
