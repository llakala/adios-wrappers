<h1 align="center">Adios Wrappers</h1>

`adios-wrappers` provides an interface for wrapping programs in Nix, and a collection of preconfigured wrappers.

There are several other community projects focused around wrappers, such as
[lassulus/wrappers](https://github.com/Lassulus/wrappers) and
[nix-wrapper-modules](https://github.com/BirdeeHub/nix-wrapper-modules). However, `adios-wrappers` is unique for
its use of [Adios](https://github.com/llakala/lladios), an alternate module system designed to be fast and
lazy.

> [!WARNING]
> Adios itself is likely to have breaking changes, although they will almost always come with warnings and a migration
> period. All major changes will be listed in the [changelog](https://github.com/llakala/lladios/blob/main/CHANGELOG.md).

## Why Adios?

A major reason why NixOS rebuilds are so slow is because of `lib.evalModules`. Nix is a lazy language, which means in
most circumstances, code/data that isn't used is never evaluated. However, `lib.evalModules` takes very little advantage
of this. Any module is able to "mutate" another one, which means that to evaluate a single module, Nix has to evaluate
all the other modules to look for mutations.

This means that as a module set grows, it will get slower and slower[^1]. This could hypothetically be avoided with a more
minimal `baseModules` list, but `lib.evalModules` isn't designed to handle module inputs explicitly, and any cycles
would lead to infinite recursion. It would also be a massively breaking change to any module set.

This fatal flaw applies to any repo that relies on `lib.evalModules` - such as
[NixOS](https://github.com/NixOS/nixpkgs/tree/master/nixos),
[home-manager](http://github.com/nix-community/home-manager/), [nixvim](https://github.com/nix-community/nixvim),
[stylix](https://github.com/nix-community/stylix), [treefmt-nix](https://github.com/numtide/treefmt-nix), and many more.

So, if a real fix would be a breaking change, why don't we just design a better module system? That's where Adios comes
in. In Adios, modules explicitly state their dependency relationships, and are therefore fully lazy. If you don't use a
module, it will never be evaluated.

Adios is less documented, weirder, and harder to use than `lib.evalModules`. But by using it, `adios-wrappers` can
_promise_ to never regress in performance, no matter how many modules it has.

## Why wrappers?

Most NixOS / Nix users configure their dotfiles via [home-manager](https://github.com/nix-community/home-manager/). This
works similarly to [stow](https://linux.die.net/man/8/stow) or [chezmoi](https://github.com/twpayne/chezmoi), but
changes are applied on rebuild, rather than through an external command. Unfortunately, this creates a very slow
feedback loop for applying any changes, as Nix has to evaluate and build an entire generation. The configured programs
are also non-portable to other systems, as the system needs to have home-manager installed already.

Wrappers work differently. Instead of declaring files to be symlinked to the home directory, wrappers simply wrap
_around_ a single derivation to embed some program config. By wrapping `pkgs.git`, we can get a new derivation,
`git-wrapped`. This provides a custom Git binary that knows about our config!

By using wrappers, we get:

1. Faster iteration, as wrappers only have to evaluate and build what you're currently working on. Most adios-wrappers
   users use a devshell for their wrappers, and can achieve 1-2 seconds of evaluation time.
2. Portability, as the wrapped program can be run on any machine with Nix on it. If you expose the wrappers via a flake,
   you can even use `nix run github:your-repo#your-program`.

For more info on the benefits of wrappers, see [this
blogpost](https://fzakaria.com/2025/07/07/home-manager-is-a-false-enlightenment).

## Installation

### Flakes

See the example config [here](./examples/flakes), which contains both a `flake.nix` and a `wrappers.nix`. Even if you
have an existing flake, the relevant parts of the example flake can simply be copied into yours.

### Non-flakes

Note: while the examples here are npins-specific, any source pinning tool should work similarly.

Start out by pinning the relevant sources:

```bash
npins init # Only if you don't already have an `npins/` folder
npins add github llakala lladios -b main --name adios
npins add github llakala adios-wrappers -b main
```

Once you've done that, see the example npins-based config [here](./examples/npins). This contains both a `wrappers.nix`
and `shell.nix`.

## Usage

See the usage instructions [here](./docs/usage.md).

## Searching for options

You're always free to inspect the modules themselves. However, in lieu of a fancy website, the repo also provides an
auto-generated JSON file with information on which options each module provides. You can find the file
[here](./docs/options.json).

## Contributing

See [the contribution guide](./docs/contributing.md).

[^1]: https://github.com/NixOS/nixpkgs/issues/57477
