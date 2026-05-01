{ inputs, config, pkgs, ... }: {
  home-manager.users.moonburst = { lib, ... }: {
    imports = [ inputs.walker.homeManagerModules.default ];
    home.packages = with pkgs; [
      wl-clipboard
      inputs.elephant.packages.${pkgs.system}.default
    ];

    home.activation.linkElephantCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p /tmp/elephant-cache
      if [ ! -L "$HOME/.cache/elephant" ]; then
        mkdir -p "$HOME/.cache"
        rm -rf "$HOME/.cache/elephant"
        ln -s /tmp/elephant-cache "$HOME/.cache/elephant"
      fi
    '';

    # Elephant Backend Service
    systemd.user.services.elephant = {
      Unit = {
        Description = lib.mkForce "Elephant - Backend for Walker";
        PartOf = lib.mkForce [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.mkForce "${inputs.elephant.packages.${pkgs.system}.default}/bin/elephant";
        # Fixes pathing and ensures it finds the DBus session
        Environment = [
          "PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils ]}:/run/current-system/sw/bin:/etc/profiles/per-user/moonburst/bin"
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
        ];
        Restart = lib.mkForce "always";
        RestartSec = lib.mkForce 5;
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # Walker Service Customization
    systemd.user.services.walker = {
      Unit = {
        Description = lib.mkForce "Walker - Application Runner";
        Requires = lib.mkForce [ "elephant.service" ];
        After = lib.mkForce [ "elephant.service" "dbus.socket" ];
      };
      Service = {
        # IMPORTANT: Add the flag here to keep it resident in memory
        ExecStart = lib.mkForce "${inputs.walker.packages.${pkgs.system}.default}/bin/walker --gapplication-service";

        # Wait for Elephant to fully initialize its listeners
        ExecStartPre = lib.mkForce "${pkgs.coreutils}/bin/sleep 3";
        Environment = [
          "PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils ]}:/run/current-system/sw/bin:/etc/profiles/per-user/moonburst/bin"
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
        ];
        RestartSec = lib.mkForce 5;
        Restart = lib.mkForce "always";
      };
    };

    programs.walker = {
      enable = true;
      runAsService = true;
      config = {
        theme = "stylix-match";
        as_window = true;
        hide_action_hints = true;
        hide_return_action = true;
        placeholders.default = { input = "Search Apps or 'd [word]'..."; list = "No Results"; };
        ui = { width = 700; height = 0; };

        providers = {
          default = [ "websearch" "desktopapplications" "calc" "clipboard" "symbols" ];
          max_results_provider = { "desktopapplications" = 3; "clipboard" = 50; };
          prefixes = [
            { provider = "websearch"; prefix = "d "; }
            { provider = "websearch"; prefix = "?"; }
            { provider = "calc"; prefix = "="; }
          ];
        };
      };

      themes."stylix-match" = {
        style = let
          c = config.lib.stylix.colors.withHashtag;
          font = config.stylix.fonts.sansSerif.name;
        in ''
          * { all: unset; font-family: "${font}"; }

          /* Main wrapper - Outer border */
          .box-wrapper {
            background-color: ${c.base00};
            padding: 8px;
            border-radius: 12px;
            border: 4px solid ${c.base0E};
            min-height: 0px;
          }

          .input {
            caret-color: ${c.base05};
            background-color: ${c.base01};
            padding: 8px;
            color: ${c.base05};
            border-radius: 8px;
            border: 4px solid ${c.base0E};
            margin-bottom: 5px;
            font-size: 16pt;
          }

          /* Restore Left Panel Border */
          .list {
            color: ${c.base05};
            border: 4px solid ${c.base0E};
            border-radius: 10px;
            padding: 4px;
            margin-right: 5px;
          }

          /* Restore Right Panel Border */
          .preview {
            border: 4px solid ${c.base0E};
            border-radius: 10px;
            background-color: ${c.base01};
            padding: 8px;
            margin-left: 5px;
          }

          /* Highlights and Text Sizes */
          .item-box { border-radius: 6px; padding: 6px; }
          child:selected .item-box { background-color: alpha(${c.base07}, 0.3); }
          .item-text { color: ${c.base05}; font-size: 20pt; font-weight: bold; }
          .item-subtext { font-size: 24px; color: ${c.base0D}; }
          .item-quick-activation { color: ${c.base05}; font-size: 20pt; font-weight: bold; margin-left: 10px; }

          scrollbar { opacity: 0; }
          .icon { margin-right: 10px; -gtk-icon-size: 32px; }
        '';
      };
    };
  };
}
