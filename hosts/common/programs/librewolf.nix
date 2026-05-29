{ pkgs, config, ... }:

let
  # Extract your live active Stylix hex strings from the top-level system scope
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
    # Ensures native messaging manifests are installed for LibreWolf/Browserpass
    programs.browserpass.enable = true;

    programs.librewolf = {
      enable = true;


      profiles.default = {
        id = 0;
        name = "default";
        isDefault = true;

        # Declarative extension management
        extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
          darkreader
          browserpass
          sponsorblock
          simple-tab-groups
          stylus
          tampermonkey
          ublock-origin
          youtube-nonstop
          betterttv
        ];

        # Framework engine customization settings
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
          "privacy.fingerprintingProtection.overrides" = "+AllTargets,-CSSPrefersColorScheme";
          "layout.css.prefers-color-scheme.content-override" = 0;
          "ui.systemUsesDarkTheme" = 1;
          "extensions.quarantinedDomains.enabled" = false;

        };
      };
    };

    # =========================================================================
    # THE NIX WAY: DIRECT USERCONTENT.CSS INJECTION INTO USER PROFILE DIRECTORY
    # =========================================================================
    home.file.".librewolf/default/chrome/userContent.css".text = ''
      /* ==========================================
       * 1. STYLIX GLOBAL WEB THEME (ALL SITES)
       * ==========================================
       */
      @-moz-document regexp("http://.*"), regexp("https://.*") {
          :root {
              color-scheme: dark !important;
          }

          body, html, main, #main, #content, div#page-manager, ytd-app {
              background-color: #'' + stylixColors.base00 + '';
          }

          *, h1, h2, h3, h4, h5, h6, p, span, div, yt-formatted-string {
              color: #'' + stylixColors.base05 + '';
          }

          a, a * {
              color: #'' + stylixColors.base0D + '' !important;
          }

          input, textarea, select, button {
              background-color: #'' + stylixColors.base01 + '' !important;
              color: #'' + stylixColors.base05 + '' !important;
              border: 1px solid #'' + stylixColors.base03 + '' !important;
          }
      }

      /* ==========================================
       * 2. CUSTOM TUMBLR WIDE TEXT SPACE FIXES (NIX INJECTION PATHWAY)
       * ==========================================
       */
      @-moz-document domain("tumblr.com") {

          /* Overwrites custom obfuscated UI properties with your dynamic base0B grey */
          :root, [data-theme], body, html, main, div,
          .CX_9D, .qWqk3, [class*="chat"], [class*="message"] {
              --content-ui: #'' + stylixColors.base0B + '' !important;
              --color-accent: #'' + stylixColors.base0B + '' !important;
              --brand-color: #'' + stylixColors.base0B + '' !important;
              --accent: #'' + stylixColors.base0B + '' !important;
              --interactive-accent: #'' + stylixColors.base0B + '' !important;
              --brand-sky-blue: #'' + stylixColors.base0B + '' !important;
              --accent-color: #'' + stylixColors.base0B + '' !important;
              --bubble-bg: #'' + stylixColors.base0B + '' !important;
              --content-text-on-ui: #ffffff !important;
          }

          .CX_9D, .qWqk3,
          div[style*="0, 184, 255"], div[style*="00b8ff"],
          [class*="chat_"], [class*="bubble_"], [class*="message_"] {
              background-color: #'' + stylixColors.base0B + '' !important;
              border-color: #'' + stylixColors.base0B + '' !important;
              color: #ffffff !important;
          }

          /* HIGH-PRIORITY FONTS: CRITICAL RESIZING SCALE MODIFIED TO 25PX FOR SANDBOX TESTING */
          div.CX_9D, div.qWqk3,
          div.CX_9D *, div.qWqk3 *,
          [class*="chat_"] *, [class*="bubble_"] *, [class*="message_"] *,
          [class*="CX_9D"] *, [class*="qWqk3"] *,
          span, p, div, li, a, yt-formatted-string,
          .j17Mp *, .be6E9 *, .CvL1C *, .gCivL * {
              font-size: 25px !important;
              line-height: 1.65 !important;
          }

          /* Target wrapper classes and eliminate vertical spacing gaps */
          .peQ_s, .post-container, .posts-list-item,
          .CxMIf, .stream-container, .main-stream-content, .items-list {
              margin-bottom: 0 !important;
              padding-bottom: 0 !important;
              margin-top: 0 !important;
              padding-top: 0 !important;
              gap: 0px !important;
          }

          html, body {
              margin: 0 !important;
              padding: 0 !important;
              height: auto !important;
              min-height: 0 !important;
          }

          .DMq0a img {
              width: 100% !important;
              height: auto !important;
              display: block;
          }

          .j17Mp, .be6E9 {
              width: 1500px !important;
              max-width: 95vw !important;
              min-height: calc(50vh) !important;
              max-height: none !important;
              transform-origin: bottom right;
          }

          .CvL1C, .gCivL {
              width: 1500px !important;
              max-width: 95vw !important;
              min-height: calc(1vh) !important;
              max-height: none !important;
          }

          .j17Mp, .be6E9, .CvL1C, .gCivL {
              margin-top: 0 !important;
              margin-bottom: 0 !important;
              margin-left: auto;
              margin-right: auto;
          }

          .j17Mp + .j17Mp, .j17Mp + .be6E9, .j17Mp + .CvL1C, .j17Mp + .gCivL,
          .be6E9 + .j17Mp, .be6E9 + .be6E9, .be6E9 + .CvL1C, .be6E9 + .gCivL,
          .CvL1C + .j17Mp, .CvL1C + .be6E9, .CvL1C + .CvL1C, .CvL1C + .gCivL,
          .gCivL + .j17Mp, .gCivL + .be6E9, .gCivL + .CvL1C, .gCivL + .gCivL {
              margin-top: 0 !important;
              padding-top: 0 !important;
          }

          .j17Mp > *, .be6E9 > *, .CvL1C > *, .gCivL > * {
              max-width: 100% !important;
              width: 1000% !important;
              box-sizing: border-box;
              padding: 0 20px !important;
          }

          .j17Mp p, .j17Mp h1, .j17Mp h2, .j17Mp h3, .j17Mp ul, .j17Mp ol, .j17Mp li,
          .be6E9 p, .be6E9 h1, .be6E9 h2, .be6E9 h3, .be6E9 ul, .be6E9 ol, .be6E9 li,
          .CvL1C p, .CvL1C h1, .CvL1C h2, .CvL1C h3, .CvL1C ul, .CvL1C ol, .CvL1C li,
          .gCivL p, .gCivL h1, .gCivL h2, .gCivL h3, .gCivL ul, .gCivL ol, .gCivL li {
              margin-top: 0 !important;
              margin-bottom: 0 !important;
              padding-top: 0 !important;
              padding-bottom: 0 !important;
          }
      }
    '';

    # Apply structural interface themes across LibreWolf profile targets
    stylix.targets.librewolf = {
      enable = true;
      profileNames = [ "default" ];
    };
  };
}
