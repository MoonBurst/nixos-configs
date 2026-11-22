{ pkgs, config, ... }:

let
  stylixColors = config.lib.stylix.colors;
in
{
  # 1. System-Level Environment Deployment Layer
  environment.systemPackages = [
    pkgs.librewolf
    pkgs.browserpass
  ];

  # 2. Consolidated User Home-Manager Profile Target Configuration
  home-manager.users.moonburst = { ... }: {
    programs.browserpass.enable = true;

    programs.librewolf = {
      enable = true;

      profiles.default = {
        id = 0;
        name = "default";
        isDefault = true;

        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          darkreader
          browserpass
          sponsorblock
          simple-tab-groups
          tampermonkey
          ublock-origin
          youtube-nonstop
          betterttv
        ];

        settings = {
          "browser.startup.page" = 3;
          "browser.sessionstore.resume_from_crash" = true;
          "privacy.clearOnShutdown.history" = false;
          "privacy.clearOnShutdown.cookies" = false;
          "privacy.clearOnShutdown.sessions" = false;
          "privacy.clearOnShutdown_v2.cookiesAndStorage" = false;
          "privacy.clearOnShutdown_v2.history" = false;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "privacy.antiFingerprinting.webcompat" = true;
          "extensions.webextensions.restrictedDomains" = "";
          "security.csp.enable" = true;
          "privacy.resistFingerprinting" = false;
          "extensions.autoDisableScopes" = 0;
          "privacy.fingerprintingProtection" = true;
          "privacy.fingerprintingProtection.overrides" = "+AllTargets,-CSSPrefersColorScheme,-JSDateTimeUTC";
          "layout.css.prefers-color-scheme.content-override" = 0;
          "ui.systemUsesDarkTheme" = 1;
          "extensions.quarantinedDomains.enabled" = false;
        };
      };
    };

    # Override LibreWolf desktop entry to force RX 6400
    xdg.desktopEntries.librewolf = {
      name = "LibreWolf";
      genericName = "Web Browser";
      exec = "env MESA_VK_DEVICE_SELECT=1002:743f! DRI_PRIME=pci-0000_2b_00_0 librewolf %u";
      icon = "librewolf";
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

    home.file.".librewolf/default/chrome/userContent.css".text = ''
      @-moz-document regexp("http://.*"), regexp("https://.*") {
          :root {
              color-scheme: dark !important;
          }

          body, html, main, #main, #content, div#page-manager, ytd-app {
              background-color: #${stylixColors.base00};
          }

          *, h1, h2, h3, h4, h5, h6, p, span, div, yt-formatted-string {
              color: #${stylixColors.base05};
          }

          a, a * {
              color: #${stylixColors.base05} !important;
          }

          /* Let pages keep their own text color on elements explicitly
             marked as buttons, instead of forcing the stylix link color.
             Applies on every site (no domain scoping) -- e.g. covers
             moonburst.net's .btn links. Note: ".btn" is also used by many
             Bootstrap-based sites, so this will let their button text
             revert to its own author color too, wherever a page uses that
             same class name. */
          a.btn, a.btn:link, a.btn:visited, a.btn *,
          a.button, a.button:link, a.button:visited, a.button * {
              color: revert !important;
          }

          input, textarea, select, button {
              background-color: #${stylixColors.base01} !important;
              color: #${stylixColors.base05} !important;
              border: 1px solid #${stylixColors.base03} !important;
          }
      }
    '';

    stylix.targets.librewolf = {
      enable = true;
      profileNames = [ "default" ];
    };
  };
}
