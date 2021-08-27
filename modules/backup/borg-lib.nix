{ lib, myLib, ... }:

with lib;

rec {
  # Creates a path string from a repo suitable for borg consumption
  buildPath = repo: if (repo.path != null) then repo.path else "ssh://${repo.remote.user}@${repo.remote.hostname}/${repo.remote.path}";

  # TODO: does this work for remote?
  latestArchive = repo: "$(borg list --last 1 --format '{archive}' ${buildPath repo})";

  # TODO: does this work for remote?
  repoNotEmpty = repo: "[ $(borg list ${buildPath repo} | wc -l) -ne 0 ]";

  
  allowUnencryptedRepo = repo: optionalString (repo.encryption.mode == "none") "export BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes";
  exportPassphrase = repo: optionalString (repo.encryption.mode != "none") "export BORG_PASSPHRASE=${myLib.passwd.cat repo.encryption.passphraseFile}";
  setBorgRSH = repo: optionalString (repo.remote != null) "export BORG_RSH='ssh -i ${repo.remote.key} -o StrictHostKeyChecking=no'";

  setEnv = repo: ''
    ${allowUnencryptedRepo repo}
    ${exportPassphrase repo}
    ${setBorgRSH repo}
  '';
}
