{ stdenv, fetchzip }:

stdenv.mkDerivation rec {
  pname = "osTicket";
  version = "1.15.2";

  src = fetchzip {
    url = "https://github.com/osTicket/osTicket/releases/download/v1.15.2/${pname}-v${version}.zip";
    sha256 = "3agOy5cDlqIO7lW3v01iZ6n4Jj0XQiJG7z7SzUgqE4E=";
    stripRoot = false;
  };

  installPhase = ''
    mkdir -p $out
    cp -r * $out
  '';
}
