{ stdenv }:

stdenv.mkDerivation {
  pname = "oomox-moon-icon-theme";
  version = "1.0";

  src = ./.; 
  themeDirName = "oomox-Moon Theme"; 

  installPhase = ''
    mkdir -p $out/share/icons
    cp -r $src/"$themeDirName" $out/share/icons/
  '';
}
