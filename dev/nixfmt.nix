{ nixfmt, fetchFromGitHub }:

nixfmt.overrideAttrs {
  src = fetchFromGitHub {
    owner = "llakala";
    repo = "nixfmt";
    rev = "0fdf54e8a6f155d501a455efa2625bd8817cb08e";
    hash = "sha256-MneyMWkcdezE6Gjt4PS5qj05LOsChYcBTtYY0Enjoos=";
  };
}
