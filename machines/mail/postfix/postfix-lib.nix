# TODO: does it need config? can I pass cfg?
{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.machines.postfix;
in
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

  mapToPath = map: "${map.path}/${map.name}";

  mapToMain = map: "${map.type}:${mapToPath map}";

  mapToFile = 
  let
    entryToStr = name: value: "${name} ${value}";
  in
  pfMap: 
  if (builtins.typeOf pfMap.contents == "set") 
  then pkgs.writeText pfMap.name (concatStringsSep "\n" (mapAttrsToList (entryToStr) pfMap.contents))
  else pkgs.writeText pfMap.name (concatStringsSep "\n" (flatten (map (entry: mapAttrsToList (entryToStr) entry) pfMap.contents))) # Else, it's a list of attrs
  ;

  # Returns an array of the value of all maps
  mapsContents = mapAttrsToList (name: value: value) cfg.maps;

  # TODO: Set better permissions.
  # TODO: The maildir format (user/) is set twice. Once here and once in the virtual map
  usersToTmpfiles = map (user: "d ${cfg.mailPath}/${user}/ 0755 ${cfg.mailUser} ${cfg.mailUser} - -") cfg.users;

  mapsToTmpfiles = map (pfMap: "L ${mapToPath pfMap} - ${cfg.mailUser} ${cfg.mailUser} - ${mapToFile pfMap}") mapsContents;

  # XXX: Pretty confusing mixing the postfix map with the function map. Using pfMap for "postfix map"
  generateDatabases = concatStringsSep "\n" (map (pfMap: "postmap ${mapToMain pfMap}") (filter (pfMap: pfMap.type == "hash") mapsContents));

}
