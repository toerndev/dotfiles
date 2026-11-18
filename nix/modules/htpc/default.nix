{ config, pkgs, ... }:
let
  kodi = pkgs.kodi-gbm.withPackages (p: with p; [
    jellyfin
    youtube
  ]);
in
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # Required for Steam
    extraPackages = with pkgs; [
      mesa
      libdrm
      libvdpau-va-gl
      libva-vdpau-driver
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
  services.pulseaudio.enable = false;

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

  # Boot straight into Kodi: autologin on tty1 starts it from the login shell.
  # Quitting Kodi leaves that shell (Kodi's GBM mode can't switch TTYs, so this
  # is the way out); `kodi-standalone` starts it again. Kodi restarts only
  # after a crash (kodi-standalone's own loop).
  services.getty.autologinUser = "htpc-user";
  environment.loginShellInit = ''
    if [ "$USER" = htpc-user ] && [ "$(tty)" = /dev/tty1 ]; then
      ${kodi}/bin/kodi-standalone
    fi
  '';

  environment.systemPackages = with pkgs; [
    kodi
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
