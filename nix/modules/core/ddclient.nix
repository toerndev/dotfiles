{ config, ... }:
{
  services.ddclient = {
    enable = true;
    protocol = "cloudflare";
    zone = "datasvard.com";
    username = "token";
    domains = [ "datasvard.com" ];
    use = "web, web=https://checkip.amazonaws.com/";
    ssl = true;
    interval = "5min";
    passwordFile = config.sops.secrets.ddclient_password.path;
  };
}
