{ pkgs, config, ... }:

let
  browserpassID = "naepdomgkenhinolocfifgehidddafch";
  browserpassManifest = {
    name = "com.github.browserpass.native";
    description = "Browserpass native messaging host";
    path = "${pkgs.writeShellScript "browserpass-wrapper" ''
      export PATH=$PATH:${pkgs.pass}/bin:${pkgs.gnupg}/bin
      exec ${pkgs.browserpass}/bin/browserpass "$@"
    ''}";
    type = "stdio";
    allowed_origins = [ "chrome-extension://${browserpassID}/" ];
  };

  extensionIds = [
    browserpassID
    "gighmmpiobklfepjocnamgkkbiglidom"
    "bchhlccjhoedhhegglilngpbnldfcidc"
    "eimadpbcbfnmbkopoojfekhnkhdbieeh"
    "mnjggcdmjocbbbhaepdhchncahnbgone"
    "clngdbkpkpeebahjckkjfobafhncgmne"
    "dhdgffkkebhmkfjojejmpbldmpobfkfo"
    "bpaoeijjlplfjbagceilcgbkcdjbomjd"
    "cjpalhdlnbpafiamejdnhcphjbkeiagm"
    "nlkaejimjacpillmajjnopmpbkbnocid"
    "igeehkedfibbnhbfponhjjplpkeomghi"
  ];
in
{
  stylix.targets.chromium.enable = true;

  # System Level Policy
  environment.etc."brave/policies/managed/extensions.json".text = builtins.toJSON {
    ExtensionInstallForcelist = extensionIds;
    # Force Restore Session (1 = Restore last session, 4 = Restore last session and ignore crash prompts)
    RestoreOnStartup = 1;
    HideCrashRestoreBubble = true;
  };

  home-manager.users.moonburst = { config, pkgs, ... }: {
    services.gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-qt;
    };

    programs.chromium = {
      enable = true;
      package = pkgs.brave;
      extensions = map (id: { inherit id; }) extensionIds;
      # Added --force-prefers-reduced-motion=shifted to disable motion
      commandLineArgs = [
        "--password-store=basic"
        "--ozone-platform-hint=auto"
        "--force-prefers-reduced-motion=shifted"
      ];
    };

    home.file.".config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.github.browserpass.native.json".text = builtins.toJSON browserpassManifest;
    home.file.".config/google-chrome/NativeMessagingHosts/com.github.browserpass.native.json".text = builtins.toJSON browserpassManifest;
  };
}
