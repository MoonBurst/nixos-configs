{ inputs, config, pkgs, lib, ... }: {
  home-manager.users.moonburst = { lib, ... }: {
    imports = [ inputs.walker.homeManagerModules.default ];

    # --- Packages ---
    home.packages = with pkgs; [
      wl-clipboard
      uni
      inputs.elephant.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # --- Activation Hooks ---
    home.activation.linkElephantCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p /tmp/elephant-cache
      if [ ! -L "$HOME/.cache/elephant" ]; then
        mkdir -p "$HOME/.cache"
        rm -rf "$HOME/.cache/elephant"
        ln -s /tmp/elephant-cache "$HOME/.cache/elephant"
      fi
    '';

    # --- Elephant Backend Service ---
    systemd.user.services.elephant = {
      Unit.Description = lib.mkForce "Elephant - Backend for Walker";
      Service = {
        ExecStart = lib.mkForce "${inputs.elephant.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/elephant";
        Restart = lib.mkForce "always";
        RestartSec = lib.mkForce 5;
        Environment = lib.mkForce [
          "PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.uni ]}:/run/current-system/sw/bin"
        ];
      };
      Install.WantedBy = lib.mkForce [ "default.target" ];
    };

    # --- Walker Service Customization ---
    systemd.user.services.walker = {
      Unit = {
        Description = lib.mkForce "Walker - Application Runner";
        Requires = lib.mkForce [ "elephant.service" ];
        After = lib.mkForce [ "elephant.service" "dbus.socket" ];
      };
      Service = {
        Type = lib.mkForce "simple";
        ExecStartPre = lib.mkForce "${pkgs.bash}/bin/bash -c '${pkgs.procps}/bin/pkill walker || true; ${pkgs.coreutils}/bin/sleep 3'";
        ExecStart = lib.mkForce "${inputs.walker.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/walker --gapplication-service";
        Restart = lib.mkForce "always";
        RestartSec = lib.mkForce 5;
        Environment = lib.mkForce [
          "PATH=${lib.makeBinPath [
            inputs.elephant.packages.${pkgs.stdenv.hostPlatform.system}.default
            pkgs.coreutils
            pkgs.procps
          ]}:/run/current-system/sw/bin"
        ];
      };
      Install.WantedBy = lib.mkForce [ "default.target" ];
    };

    # --- Walker Configuration ---
    programs.walker = {
      enable = true;
      runAsService = true;
      package = inputs.walker.packages.${pkgs.stdenv.hostPlatform.system}.default;

      config = {
        theme = "stylix-match";
        as_window = true;
        hide_action_hints = true;
        hide_return_action = true;
        ui = { width = 700; height = 0; };
        placeholders.default = {
          input = "Search Apps or 'd [word]'...";
          list = "No Results";
        };

        providers = {
          default = [ "websearch" "desktopapplications" "calc" "clipboard" "symbols" "unicode" ];
          max_results_provider = {
            "desktopapplications" = 3;
            "clipboard" = 50;
            "unicode" = 20;
            "symbols" = 3;
          };
          prefixes = [
            { provider = "websearch"; prefix = "d "; }
            { provider = "websearch"; prefix = "?"; }
            { provider = "calc"; prefix = "="; }
          ];
        };

        commands = {
          "unicode" = {
            description = "Search All Unicode";
            command = "${pkgs.bash}/bin/bash -c '${pkgs.uni}/bin/uni search . | ${inputs.walker.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/walker --dmenu'";
          };
        };
      };

      # --- Stylix Theme ---
      themes."stylix-match" = {
        style = let
          c = config.lib.stylix.colors.withHashtag;
          font = config.stylix.fonts.sansSerif.name;
        in ''
          * {
            all: unset;
            font-family: "${font}";
          }

          /* Main Container */
          .box-wrapper {
            background-color: ${c.base00};
            padding: 8px;
            border-radius: 12px;
            border: 4px solid ${c.base0E};
            min-height: 0px;
          }

          /* Search Bar */
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

          /* Result List */
          .list {
            color: ${c.base05};
            border: 4px solid ${c.base0E};
            border-radius: 10px;
            padding: 4px;
            margin-right: 5px;
          }

          /* Preview Panel */
          .preview {
            border: 4px solid ${c.base0E};
            border-radius: 10px;
            background-color: ${c.base01};
            padding: 8px;
            margin-left: 5px;
          }

          /* Item Styling */
          .item-box {
            border-radius: 6px;
            padding: 6px;
          }

          child:selected .item-box {
            background-color: alpha(${c.base07}, 0.3);
          }

          /* Text Elements */
          .item-text {
            color: ${c.base05};
            font-size: 20pt;
            font-weight: bold;
          }

          .item-subtext {
            font-size: 24px;
            color: ${c.base0D};
          }

          .item-quick-activation {
            color: ${c.base05};
            font-size: 20pt;
            font-weight: bold;
            margin-left: 10px;
          }

          /* Icons and Scrollbar */
          .icon {
            margin-right: 10px;
            -gtk-icon-size: 32px;
          }

          scrollbar {
            opacity: 0;
          }
        '';
      };
    };
  };
}
