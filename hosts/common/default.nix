{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./audio.nix
    ./btrfs.nix
    ./dunst/dunst.nix
    ./mime.nix
    ./obs.nix
    ./packages.nix
    ./security.nix
    ./services.nix
    ./theme.nix
    ./users.nix
    ./zsh.nix
    ./programs/waybar/default.nix
    ./programs/brave.nix
    ./programs/audacious.nix
  ];

  home-manager.users.moonburst = {
    imports = [
      ./programs/sway/sway.nix
    ];

    xdg.configFile."qt5ct/qt5ct.conf".force = true;
    xdg.configFile."qt6ct/qt6ct.conf".force = true;

    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "sway";
    };

    programs.kitty = {
      enable = true;
      settings = {
        confirm_os_window_close = 0;
        "map alt+up" = "scroll_line_up";
        "map alt+down" = "scroll_line_down";
        "map alt+page_up" = "scroll_page_up";
        "map alt+page_down" = "scroll_page_down";
        "map alt+delete" = "send_text all \\x1bd";
      };
    };
  };

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocales = [ "en_US.UTF-8/UTF-8" ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    max-jobs = lib.mkDefault "auto";
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}
