{
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  cliphist,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "sherlock-clipboard";
  version = "0-unstable-2025-11-01";

  src = fetchFromGitHub {
    owner = "Skxxtz";
    repo = "sherlock-clipboard";
    rev = "9c6600d467e1ea81cfd70f8f4fc9b8e135b1363c";
    hash = "sha256-agCRAEkfi3PCvKeWfOgcLfEHZGiW8sBBAQl3BewYE/0=";
  };

  cargoHash = "sha256-D2/L7vQkjEgawde9cZH45s0FSLluihqYSSwW5eLNMxM=";

  buildInputs = [ cliphist ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Custom plugin for Sherlock adding clipboard history support";
    homepage = "https://github.com/Skxxtz/sherlock-clipboard";
    license = lib.licenses.gpl3Only;
    mainProgram = "sherlock-clp";
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [
      cybardev
    ];
  };
})
