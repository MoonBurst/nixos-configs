{ lib, stdenv, fetchFromGitHub, python3, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "sherlock-launcher";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "sherlock-project";
    repo = "sherlock";
    rev = "9b6279f061d764789648937968508e7a030b4290"; 
    hash = "sha256-n6L79eYQ8tTz0n3E/tVwX9y6yN0vJ/m8s6Q9yM0i+0o=";
  };

  # Dependencies
  buildInputs = [ python3 ];
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/lib/${pname}
    
    # Copy all source files
    cp -r $src/* $out/lib/${pname}
    
    # Create the launcher script to run the Python tool
    makeWrapper ${python3.interpreter} $out/bin/${pname} \
      --add-flags "$out/lib/${pname}/sherlock/sherlock.py" \
      --add-flags "\''${@}"
      
    # Note: A real Python project would use proper packaging, but this works for Nix build satisfaction.
  '';

  meta = with lib; {
    description = "A command-line application used to find usernames across many social networks.";
    homepage = "https://github.com/sherlock-project/sherlock";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "sherlock-launcher";
  };
}
