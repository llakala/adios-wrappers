{
  # TODO: FIXME: point back to main when merging this
  inputs.adios.url = "github:llakala/adios/verify-assertions"; # My personal fork

  outputs = inputs: {
    wrapperModules = import ./default.nix {
      adios = inputs.adios;
    };
  };
}
