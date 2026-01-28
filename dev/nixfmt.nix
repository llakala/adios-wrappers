{ nixfmt, fetchFromGitHub }:

nixfmt.overrideAttrs {
  src = fetchFromGitHub {
    owner = "llakala";
    repo = "nixfmt";
    rev = "66d35eddc8ccbe833a8fbac9cd3a3e0015283d97";
    hash = "sha256-1UE28LaQLKR2ZnHts7Sz2hIyZnaVz14s45A9LfNi60A=";
  };
}
