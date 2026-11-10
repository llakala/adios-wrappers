{ types, promise, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    configFile = {
      type = types.pathLike;
      description = ''
        `xmonad.hs` file to be injected into the wrapped package.

        See the [documentation](https://xmonad.org/TUTORIAL.html) for syntax and valid options.
      '';
    };

    haskellPackages = {
      type = types.attrs;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.haskellPackages);
      description = ''
        haskellPackages set used to build xmonad. This can be used
        to change the GHC version used to build xmonad and the
        packages listed in {var}`extraPackages`.
      '';
    };

    extraPackages = {
      type = types.function;
      default = _: [];
      example = ''
        hp: [
          hp.xmonad-contrib
          hp.xmonad-extras
        ]
      '';
      description = ''
        A function returning a list of extra packages to be made
        available to ghc when recompiling xmonad.

        You probably want to add `xmonad-contrib` here.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ options }: options.haskellPackages.xmonad);
      description = ''
        The xmonad package to be wrapped.
      '';
    };
  };

  assertions = [
    {
      verify = { options }: options ? configFile;
      explain = _: "'options.configFile' must be set";
    }
  ];

  inputs.mkWrapper.options = promise (
    { inputs, options }:
    let
      inherit (inputs.nixpkgs.pkgs) writers xmessage;
      inherit (inputs.nixpkgs.lib) getExe getExe';
      inherit (options) haskellPackages extraPackages;
      xmonadEnv = haskellPackages.ghcWithPackages (self: [ options.package ] ++ extraPackages self);
    in {
      pname = "xmonad";
      package =
        writers.writeHaskellBin "xmonad"
          {
            inherit (haskellPackages) ghc;
            libraries = [ options.package ];
          }
          # We need to use XMONAD_CONFIG_DIR for our wrapper, but
          # xmonad will only honour it if the two corresponding
          # env vars are set, so set them here to the xdg values.
          #
          # https://github.com/xmonad/xmonad/blob/master/src/XMonad/Core.hs#L528
          # https://github.com/xmonad/xmonad/blob/master/src/XMonad/Main.hs#L66
          ''
            import XMonad
            import Control.Monad (when)
            import Data.Maybe (isNothing)
            import System.Directory
            import System.Environment

            setCustom :: String -> XdgDirectory -> IO ()
            setCustom var xdg = do
              cur <- lookupEnv var
              when (isNothing cur) $ do
                dir <- getXdgDirectory xdg "xmonad"
                createDirectoryIfMissing True dir
                setEnv var dir

            main :: IO ()
            main = do
              setCustom "XMONAD_DATA_DIR" XdgData
              setCustom "XMONAD_CACHE_DIR" XdgCache
              xmonad def
          '';
      preWrap = ''
        install -D ${xmonadEnv}/share/man/man1/xmonad.1.gz $out/share/man/man1/xmonad.1.gz
      '';
      symlinks = {
        "$out/xmonad/xmonad.hs" = options.configFile;
      };
      environment = {
        XMONAD_GHC = getExe' xmonadEnv "ghc";
        XMONAD_XMESSAGE = getExe xmessage;
        XMONAD_CONFIG_DIR = "$out/xmonad";
      };
    }
  );

  result = promise ({ results }: results.mkWrapper);

  meta = {
    maintainers = [ "choco" ];
  };
}
