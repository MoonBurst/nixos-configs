# --- security.nix ---
{ config, pkgs, inputs, lib, ... }: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # --- Shared Secrets (SOPS) ---
  sops = {
    defaultSopsFile = ../../secrets.yaml;
    defaultSopsFormat = "yaml";

    age.keyFile = "/home/moonburst/.config/sops/age/moon_keys.txt";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      # --- System & User Secrets ---
      moonburst_password = { neededForUsers = true; };
      sops_key = { neededForUsers = true; };
      borg_passphrase = { };
      nextcloud_url = { };
      nextcloud_user = { };
      nextcloud_pass = { };
      weather_api_key.owner = "moonburst";
      weather_city.owner = "moonburst";
      gmail_app_password.owner = "moonburst";
      gmail_address.owner = "moonburst";
    };
  };

  systemd.tmpfiles.rules = [
    "d /home/moonburst/.config/sops/age 0700 moonburst users - -"
  ];

  # --- SSH Server Settings ---
  services.openssh = {
    enable = true;
    listenAddresses = [
      { addr = "0.0.0.0"; port = 22; }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      GatewayPorts = "yes";
    };
  };

  # --- Tailscale Private Network (Global Remote Access) ---
  services.tailscale.enable = true;
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # --- Local Network Autodiscovery (mDNS Fallback) ---
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # --- SSH Client Configuration ---
  programs.ssh = {
    startAgent = false;
    extraConfig = ''
      Host moonbeauty
        HostName 100.126.102.63
        User moonburst

      Host lunarchild
        HostName 100.81.66.61
        User moonburst
    '';
  };

  security.pam.services.quickshell = {};
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
  services.xserver.displayManager.lightdm.enable = false;

  security.pam.services.swaylock = {};
  services.gnome.gcr-ssh-agent.enable = false;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
  programs.fuse.userAllowOther = true;
  security.polkit.enable = true;
  security.rtkit.enable = true;
  boot.tmp.useTmpfs = true;
  environment.systemPackages = with pkgs; [
    sops age pass authenticator cloudflared
  ];
}
