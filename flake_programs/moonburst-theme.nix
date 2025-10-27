{ stdenv, fetchFromGitHub, lib }:

stdenv.mkDerivation rec {
  pname = "moon-burst-theme";
  version = "2025-10-12";

  src = fetchFromGitHub {
    owner = "MoonBurst";
    repo = "Dotfiles";
    rev = "7b105f8450938c12a130fdadcd5b31f247de621a";
    hash = "sha256-ewQgVFfyxEuWCNk8Zva4+wXcrRn0J+xs9e+m3QSxdpo=";
  };

  installPhase = ''
    mkdir -p $out/share/themes/Moon-Burst-Theme
    cp -r $src/.local/share/themes/Moon-Burst-Theme/* $out/share/themes/Moon-Burst-Theme
  '';

  meta = with lib; {
    description = "Moon-Burst-Theme from MoonBurst/Dotfiles repository";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
