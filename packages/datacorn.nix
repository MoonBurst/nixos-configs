{
  lib,
  fetchFromGitHub,
  stdenv,
  meson,
  ninja,
  glibc,
  qt6,
}:
stdenv.mkDerivation {
  pname = "datacorn";
  version = "0-unstable-2025-12-14";

  src = fetchFromGitHub {
    owner = "ProjectIgnis";
    repo = "Datacorn";
    rev = "f91b8f2b08a4c9a04c4cf164db5619b552ba37a2";
    hash = ""; # use actual hash
  };

  nativeBuildInputs = [
    meson
    ninja
  ];

  buildInputs = [
    glibc
    qt6.qtbase
    # qt6.<other-deps>
  ];

  # installPhase = ''
  #   runHook preInstall

  #   mkdir -p $out/bin
  #   cp datacorn $out/bin

  #   runHook postInstall
  # '';

  meta = {
    description = "Database editor for Yu-Gi-Oh! cards";
    homepage = "https://github.com/ProjectIgnis/Datacorn";
    license = lib.licenses.agpl3Only;
    mainProgram = "datacorn";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = with lib.maintainers; [ ];
  };
}
