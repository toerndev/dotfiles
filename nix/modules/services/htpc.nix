{ config, pkgs, ... }:
{
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

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;  # for Steam
    pulse.enable = true;
  };
  hardware.pulseaudio.enable = false;

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
  ];

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
