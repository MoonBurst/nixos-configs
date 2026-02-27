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

  # Your full list of extension IDs
  extensionIds = [
    browserpassID
    "gighmmpiobklfepjocnamgkkbiglidom" # AdBlock
    "bchhlccjhoedhhegglilngpbnldfcidc" # AutoJoin for SteamGifts
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
    "clngdbkpkpeebahjckkjfobafhncgmne" # Stylus
    "dhdgffkkebhmkfjojejmpbldmpobfkfo" # Tampermonkey
    "bpaoeijjlplfjbagceilcgbkcdjbomjd" # TTV LOL PRO
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    "nlkaejimjacpillmajjnopmpbkbnocid" # YouTube NonStop
    "igeehkedfibbnhbfponhjjplpkeomghi" #tab manager
  ];
in
{
  # System Level Policy
  environment.etc."brave/policies/managed/extensions.json".text = builtins.toJSON {
    ExtensionInstallForcelist = extensionIds;
  };

  home-manager.users.moonburst = { config, pkgs, ... }: {
    services.gpg-agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
    };

    programs.chromium = {
      enable = true;
      package = pkgs.brave;
      extensions = map (id: { inherit id; }) extensionIds;
      commandLineArgs = [ "--password-store=basic" "--ozone-platform-hint=auto" ];
    };

    # Restore the Native Messaging bridge paths with the NEW ID
    home.file.".config/BraveSoftware/Brave-Browser/NativeMessagingHosts/com.github.browserpass.native.json".text = builtins.toJSON browserpassManifest;
    home.file.".config/google-chrome/NativeMessagingHosts/com.github.browserpass.native.json".text = builtins.toJSON browserpassManifest;
  };
}
