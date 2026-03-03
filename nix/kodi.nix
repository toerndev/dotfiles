{ config, pkgs, ... }:

{
  users.groups.kodi = {};
  users.users.kodi = {
    isSystemUser = true;
    group = "kodi";
    home = "/var/lib/kodi";
    createHome = true;
    extraGroups = [ "video" "audio" "input" "pipewire" ];
  };

  systemd.services.kodi = let
    kodiPkg = pkgs.kodi-gbm.withPackages(p: with p; [
      # svtplay
      youtube
    ]);
  in {
    enable = true;
    # wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "sound.target"
      "systemd-user-sessions.service"
    ];
    wants = [
      "network-online.target"
    ];
    serviceConfig = {
      Type = "simple";
      User = "kodi";
      # Environment = "HOME=/home/kodi";
      # WorkingDirectory = "/home/kodi";
      # SupplementaryGroups = [ "input" "video" "audio" "pipewire" ];
      ExecStart = "${kodiPkg}/bin/kodi-standalone";

      # Restart = "always";
      # TimeoutStopSec = "15s";
      # TimeoutStopFailureMode = "kill";
    };
  };
}
