{ lib, pkgs, cfg, ... }:

with lib;

rec {
  # Pretty useful in any case, put it in my lib?
  match = value: attrs: attrs."${value}" or attrs.default;

  boolToYN = bool: if bool then "y" else "n";

  boolToYesNo = bool: if bool then "yes" else "no";

  wakeupToStr = wakeup: if (wakeup == null) then "never" else (toString wakeup);

  mainAttrToStr = value: if (value == null) then "" else match (builtins.typeOf value) {
    bool = boolToYesNo value;
    list = concatStringsSep ", " value;
    default = toString value;
  };

  attrsToMainCf = name: value: "${name} = ${mainAttrToStr value}";

  attrsToMasterCf = name: value: let
    columns = [
      (if (value.name == null) then name else value.name)
      (value.type)
      (boolToYN value.private)
      (boolToYN value.unpriv)
      (boolToYN value.chroot)
      (wakeupToStr value.wakeup)
      (toString value.maxproc)
      (value.command)
    ] ++ value.args;
  in concatStringsSep " " columns;

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

  createMailboxes = map (user: "d ${cfg.mailPath}/${user}/ 0700 ${cfg.mailUser} ${cfg.mailUser} - -") cfg.users;

  mapsToTmpfiles = map (pfMap: "L ${mapToPath pfMap} - ${cfg.mailUser} ${cfg.mailUser} - ${mapToFile pfMap}") mapsContents;

  # XXX: Pretty confusing mixing the postfix map with the function map. Using pfMap for "postfix map"
  generateDatabases = concatStringsSep "\n" (map (pfMap: "postmap ${mapToMain pfMap}") (filter (pfMap: pfMap.type == "hash") mapsContents));

}
