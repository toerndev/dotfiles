{ config, ... }:
{
  services.ddclient = {
    enable = true;
    configFile = config.sops.templates."ddclient-conf".path;
  };
}
