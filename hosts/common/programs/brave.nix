{ pkgs, config, ... }:

let
  browserpassID = "naepdomgkenhinolocfifgehidddafch";

  # Standard Chrome Web Store update URL suffix
  updateUrl = ";https://clients2.google.com";

  # Formatted list for the System Policy (Forcelist)
  extensionIdsForPolicy = map (id: "${id}${updateUrl}") [
    browserpassID
    "gighmmpiobklfepjocnamgkkbiglilom" # AdBlock
    "bchhlccjhoedhhegglilngpbnldfcidc" # AutoJoin for SteamGifts
    "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
    "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
    "clngdbkpkpeebahjckkjfobafhncgmne" # Stylus
    "dhdgffkkebhmkfjojejmpbldmpobfkfo" # Tampermonkey
    "bpaoeijjlplfjbagceilcgbkcdjbomjd" # TTV LOL PRO
    "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
    "nlkaejimjacpillmajjnopmpbkbnocid" # YouTube NonStop
    "igeehkedfibbnhbfponhjjplpkeomghi" # Tab manager
  ];

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
in
{
  stylix.targets.chromium.enable = true;

  # System Level Policy
  # This section disables the "Restore pages" popup and forces extensions
  environment.etc."brave/policies/managed/policy.json".text = builtins.toJSON {
    ExtensionInstallForcelist = extensionIdsForPolicy;

    # FIX: Stops the "Brave didn't shut down correctly" bubble
    ExitTypeServiceEnabled = false;

    # FIX: Ensures it starts fresh instead of trying to recover crashed sessions
    # 5 = Open New Tab Page
    RestoreOnStartup = 1;
  };

  home-manager.users.moonburst = { config, pkgs, ... }: {
    services.gpg-agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
    };

    programs.chromium = {
      enable = true;
      package = pkgs.brave;
      # Extensions are already forced by the system policy above,
      # but we can list the IDs here for Home Manager awareness.
      extensions = map (id: { inherit id; }) [
        browserpassID
        "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
        # Add others if you want Home Manager to track them specifically
      ];
      commandLineArgs = [
        "--password-store=basic"
        "--ozone-platform-hint=auto"
      ];
    };

    # Native Messaging Hosts using XDG paths for better reliability
    xdg.configFile."BraveSoftware/Brave-Browser/NativeMessagingHosts/com.github.browserpass.native.json".text = builtins.toJSON browserpassManifest;
    xdg.configFile."google-chrome/NativeMessagingHosts/com.github.browserpass.native.json".text = builtins.toJSON browserpassManifest;
  };
}
