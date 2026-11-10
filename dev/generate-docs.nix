let
  inherit (builtins) attrNames filter getFlake isFunction mapAttrs;
  filterAttrValues = pred: set: removeAttrs set (filter (name: !pred set.${name}) (attrNames set));
  keysToRemove = [
    "defaultFunc"
    "merge"
    "default"
  ];
  flake = getFlake (toString ../.);

  # modules can opt out of docs generation by setting `meta.renderDocs = false;`
  filteredModules = filterAttrValues (
    wrapper: (wrapper.meta.renderDocs or null) != false
  ) flake.wrapperModules;
in
mapAttrs (_: wrapper: {
  options = mapAttrs (
    _: option:
    removeAttrs option keysToRemove
    // {
      type = option.type.name;
      # functions and promises can't be serialized to JSON
      ${
        if option ? default && !isFunction option.default && !option.default ? __adiosPromise then
          "default"
        else
          null
      } =
        option.default;
    }
  ) wrapper.options;
}) filteredModules
