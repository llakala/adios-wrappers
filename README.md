# adios-wrappers

## NOTE

This is a new project, which only has a small set of modules at the moment. Users are expected to have some Adios knowledge coming in.

# Installation

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

# Usage

See the usage instructions [here](./docs/usage.md).

# Searching for options

You're always free to inspect the modules themselves. However, in lieu of a fancy website, the repo also provides an
auto-generated JSON file with information on which options each module provides. You can find the file
[here](./docs/options.json).

# Contributing

See [the contribution guide](./docs/contributing.md).
