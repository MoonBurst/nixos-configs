{ pkgs, config, inputs, ... }:

{
  environment.systemPackages = [ pkgs.ungoogled-chromium pkgs.browserpass ];

  programs.chromium = {
    enable = true;
    extraOpts = {
      "BrowserSignin" = 0;
      "SyncDisabled" = true;
      "MetricsReportingEnabled" = false;
      "UserFeedbackAllowed" = false;
      "WebRtcIPHandling" = "disable_non_proxied_udp";
      "PrivacySandboxAdTopicsEnabled" = false;
      "PrivacySandboxSiteEnabledAdsEnabled" = false;
    };
  };

  stylix.targets.chromium.enable = true;

  home-manager.users.moonburst = { ... }: {
    imports = [ inputs.chromexup.homeManagerModules.default ];

    programs.browserpass = { enable = true; browsers = [ "chromium" ]; };

    programs.chromexup = {
      enable = true;
      extensions = {
        DarkReader = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
        Browserpass = "naepdomgkenhinolocfifgehidddafch";
        SponsorBlock = "mnjggcdmjocbbbhaepdhchncahnbgone";
        Tampermonkey = "dhdgffkkebhmkfjojejmpbldmpobfkfo";
        YouTubeNonStop = "hbmcblniemifdlipacdemiiaakikbign";
        BetterTTV = "ajopnjidmegmdimjlfnijceegpefgped";
        TabSessionManager = "iaiomicjabeggjcfkbimgmglanimpnae";
        Unhook = "khncfooichmfjbepaaaebmommgaepoid";

        # We removed UBlockOrigin from here because chromexup can't download MV2
      };
    };

    programs.chromium = {
      enable = true;
      package = pkgs.ungoogled-chromium;

      # Here we manually inject uBlock Origin using the GitHub workaround
      extensions = [
        {
          id = "blockjmkbacgjkknlgpkjjiijinjdanf"; # uBlock Origin (Community MV2 build)
          crxPath = pkgs.fetchurl {
            url = "https://github.com/imputnet/ublock-origin-crx/releases/download/1.76.0/uBlock0_1.76.0.crx";
            sha256 = "sha256-PHg1uoMXWpX7RHdjBbVFceR307PL87Dsc3vT9qnlv3k=";
          };
          version = "1.76.0";
        }
      ];

      commandLineArgs = [
        "--use-angle=vulkan"
        "--ignore-gpu-blocklist"
        "--enable-zero-copy"
        "--enable-features=VaapiVideoDecoder,VaapiIgnoreDriverChecks"
        # These flags force Chromium 131 to allow Manifest V2 extensions
        "--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled"
      ];
    };

    xdg.desktopEntries.chromium = {
      name = "Ungoogled Chromium";
      genericName = "Web Browser";
      exec = "env MESA_VK_DEVICE_SELECT=1002:743f! DRI_PRIME=pci-0000_2b_00_0 chromium %u";
      icon = "chromium";
      terminal = false;
      categories = [ "Network" "WebBrowser" ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/vnd.mozilla.xul+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
    };
  };
}
