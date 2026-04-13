{ config, lib, ... }:
{
  # DynamicUser=true (module default) breaks the prestart script's
  # `install --owner=$USER` because DynamicUser users are not in /etc/passwd.
  # Fix with a real system user.
  users.users.ddclient = { isSystemUser = true; group = "ddclient"; };
  users.groups.ddclient = {};
  systemd.services.ddclient.serviceConfig.DynamicUser = lib.mkForce false;

  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    zone = "datasvard.com";
    username = "token";
    domains = [ "datasvard.com" "cloud.datasvard.com" "wg.datasvard.com" "cms.datasvard.com" ];
    usev4 = "webv4, webv4=https://checkip.amazonaws.com/";
    usev6 = "";
    ssl = true;
    interval = "5min";
    passwordFile = config.sops.secrets.ddclient_password.path;
  };
}
