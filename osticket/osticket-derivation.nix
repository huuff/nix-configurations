{ stdenv, php74 }:

stdenv.mkDerivation rec {
  pname = "osTicket";
  version = "1.15.2";

  src = builtins.fetchurl {
    url = "https://github.com/osTicket/osTicket/archive/refs/tags/v${version}.tar.gz";
    sha256 = "1zwb2bgh97iwi1j2vaygzyfm9saw0lx14b6nim24w6y88rirr8qy";
  };

  nativeBuildInputs = [ php74 ];

  installPhase = ''
    mkdir $out
    php manage.php deploy --setup $out
  '';
}
