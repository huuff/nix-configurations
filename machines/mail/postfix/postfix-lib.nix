{ lib, ... }:

with lib;

rec {
  match = value: attrs: if (hasAttr value attrs) then attrs."${value}" else attrs.default;

  boolToYN = bool: if bool then "y" else "n";

  boolToYesNo = bool: if bool then "yes" else "no";

  wakeupToStr = wakeup: if (wakeup == null) then "never" else (toString wakeup);

  mainAttrToStr = value: match (builtins.typeOf value) {
    bool = boolToYesNo value;
    list = concatStringsSep ", " value;
    default = toString value;
  };

  attrsToMainCf = name: value: "${name} = ${mainAttrToStr value}";

  # TODO: A concatStringsSep with this and spaces (or tabs) and a list for the strings.
  attrsToMasterCf = name: value: "${if (value.name == null) then name else value.name} ${value.type} ${boolToYN value.private} ${boolToYN value.unpriv} ${boolToYN value.chroot} ${wakeupToStr value.wakeup} ${toString value.maxproc} ${value.command} ${concatStringsSep " " value.args}";
}
