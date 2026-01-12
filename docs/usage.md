Once you've installed the wrappers and have a `wrappers/default.nix` entrypoint, you'll need to actually inject your
config into the wrappers. There are multiple ways to do this, each with their own pros and cons.

## Calling impls directly

This is the simplest approach. We simply call each wrapper module like a function, to inject our config values.

While this is very simple, it has some drawbacks. It only allows you to call a single module with some options. This is
fairly limiting, and means:

1. You can't enable the mutations that are set up for shell integrations
2. You can't inject a computed value (think `defaultFunc`)
3. Modules that take another wrapper as an input won't work as expected

For this reason, I only recommend this approach if your usage of the wrapper modules is fairly minimal, or you currently
don't feel comfortable with the more advanced approach.

If you are using this method, there are two TODO comments in your `wrappers/default.nix` file. The first can be replaced
with:

```nix
root = {
  name = "root";
  modules = adios-wrappers;
};
```

And the second can be replaced with an attrset, where you call the wrapper modules you use, and inject your config:

```nix
# wrappers/default.nix
in
{
  less = wrapperModules.less {
    flags = [ "--quit-if-one-screen" ];
  };
  git = wrapperModules.git {
    settings = {
      core.email = "your.email@here.com";
    };
  };
  firefox = wrapperModules.firefox {
    policiesFiles = [ ./policies.json ];
  };
}
```

## Overriding the modules with `lib.recursiveUpdate`

This is the primary way I recommend. It requires more knowledge of how Adios works, but in return, you get a lot more
freedom.

The previous method only allowed us to call a wrapper module directly with some options - but we ended up losing all the
module set behavior. To get this back, we can inject data into the module definitions themselves. This can be done by
using `lib.recursiveUpdate`. The function works like this:

```nix
# before
lib.recursiveUpdate
{
  nested = {
    a = 1;
    b = 2;
  };
}
{
  nested = {
    a = 7;
    c = 25;
  };
}

# after
{
  nested = {
    a = 7;
    b = 2;
    c = 25;
  };
}
```

As you can see, the right attrset "updates" the left attrset, with the right attrset taking priority if there's a key collision. This
means we can take the existing modules and:

- Inject our personal configuration wth `options.$OPTION_NAME.default`
- Use computed defaults with `options.$OPTION_NAME.defaultFunc`
- Specify mutators for an option with `options.$OPTION_NAME.mutators`
- Add inputs to a module with `inputs.foo.path = "/foo";`

To use this method, replace the first TODO comment in `wrappers/default.nix`, embedding your config here:
```nix
# Alternatively, use `overrides = adios.lib.importModules ./.`. Then, each
# attribute like `less` would live under `less.nix` or `less/default.nix`. I
# recommend this in practice, I'm just declaring inline for less verbosity.
overrides = {
  less = {
    options.flags.default = [ "--quit-if-one-screen" ];
  };
  git = {
    inputs.less.path = "/less";
    options.settings.defaultFunc =
      { inputs, options }:
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
  name = "root";
  modules = pkgs.lib.recursivelyUpdate adios-wrappers overrides;
};
```

And replace the second TODO comment with:
```nix
in
builtins.mapAttrs (module: module {}) wrapperModules.root.modules
```
