{ config, pkgs, systemConfig, ... }:

{
  imports = [
    ./hardware/htpc.nix
  ];

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;
  networking.hostName = "htpc";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Required for Steam
    extraPackages = with pkgs; [
      mesa.drivers
      libdrm
      libvdpau-va-gl
      vaapiVdpau
    ];
    extraPackages32 = with pkgs; [
      driversi686Linux.mesa
    ];
  };

  # sudo e2label /dev/nvme0n1p4 media
  fileSystems."/media" = {
    device = "/dev/disk/by-label/media";
    fsType = "ext4";
  };

  # support NTFS for external media
  boot.supportedFilesystems = [ "ntfs" ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true; # for Steam
    pulse.enable = true;
  };
  hardware.pulseaudio.enable = false;

  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };
  systemd.tmpfiles.rules = [
    "d /media/movies 0755 jellyfin jellyfin -"
    "d /media/tv 0755 jellyfin jellyfin -"
    "d /media/music 0755 jellyfin jellyfin -"
    "d /media/kids 0755 jellyfin jellyfin -"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
    };
  };

  services.seatd.enable = true;

  users.groups.htpc = {};
  # must not be isSystemUser - Gamescope needs seat access
  users.users.htpc-user = {
    isNormalUser = true;
    group = "htpc";
    home = "/home/htpc";
    createHome = true;
    extraGroups = [ "video" "audio" "input" "pipewire" "seat" ];
    shell = pkgs.bash;
  };

  # strace was used for debugging Steam issues
  # security.wrappers.strace = {
  #   owner = "root";
  #   group = "root";
  #   capabilities = "cap_sys_ptrace+ep";
  #   source = "${pkgs.strace}/bin/strace";
  # };

  services.getty.autologinUser = "htpc-user";

  environment.systemPackages = with pkgs; [
    (kodi-gbm.withPackages(p: with p; [
      jellyfin
      youtube
    ]))
    cage  # `cage steam` for initial Steam cache setup in Wayland, before Gamescope will work
    lutris
    mangohud
    mpv
    # strace  # debugging tool
  ];

  # May or may not be required for Steam to start
  # fonts = {
  #   fontDir.enable = true;  # Creates /run/current-system/sw/share/X11/fonts
  #   packages = with pkgs; [
  #     dejavu_fonts  # Steam specifically looks for DejaVuSans.ttf
  #   ];
  # };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };
}
