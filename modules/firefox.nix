{ types, promise, assertions, ... }:
{
  inputs = {
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    autoConfigFiles = {
      type = types.listOf (types.either types.path types.derivation);
      description = ''
        `autoconfig.js` files to be injected into the wrapped package.

        See the Firefox [documentation](https://support.mozilla.org/en-US/kb/customizing-firefox-using-autoconfig).
      '';
    };

    policies = {
      type = types.attrs;
      description = ''
        Policies to be injected into the wrapped package.

        `policies.Preferences` can be used to inject preferences.

        Disjoint with the `policiesFiles` option.
      '';
    };
    policiesFiles = {
      type = types.listOf (types.either types.path types.derivation);
      description = ''
        JSON files containing policies to be injected into the wrapped package.

        To inject preferences, code like this can be used:
        ```json
        {
          "policies": {
            "Preferences": {
              "YOUR_PREFERENCES": "here"
            }
          }
        }
        ```

        See the Firefox [documentation](https://support.mozilla.org/en-US/kb/customizing-firefox-using-policiesjson).

        Disjoint with the `policies` option.
      '';
    };

    nativeMessagingHosts = {
      type = types.listOf types.derivation;
      description = ''
        Additional packages containing native messaging hosts that should be made available to Firefox extensions.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.firefox-unwrapped);
      description = ''
        The Firefox package to be wrapped.
        Note that this should use a `-unwrapped` variant.
      '';
    };
  };

  assertions = [
    (assertions.disjoint "policies" "policiesFiles")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) wrapFirefox;
    in
    wrapFirefox options.package {
      ${if options ? policies then "extraPolicies" else null} = options.policies;
      # From my testing, these options need to be coerced to store paths.
      # If you know of a workaround to allow impure paths to be used here,
      # please make a PR!
      ${if options ? policiesFiles then "extraPoliciesFiles" else null} = map (
        file: "${file}"
      ) options.policiesFiles;
      ${if options ? autoConfigFiles then "extraPrefsFiles" else null} = map (
        file: "${file}"
      ) options.autoConfigFiles;
      ${if options ? nativeMessagingHosts then "nativeMessagingHosts" else null} =
        options.nativeMessagingHosts;
    }
  );

  meta = {
    maintainers = [ "llakala" ];
  };
}
