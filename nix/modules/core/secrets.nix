{ config, ... }:
{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  # Decrypt using the host's SSH ed25519 key (no separate age key to manage)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets.wireguard_private_key = {};

  sops.secrets.cloudflare_api_token = {};

  sops.secrets.ddclient_password = {};

  sops.secrets.wifi_psk = {};

  sops.secrets.nextcloud_admin_password = {
    owner = "nextcloud";
  };

  # Directus JWT signing key — add to secrets/secrets.yaml before deploying.
  sops.secrets.directus_secret = {};

  # Directus bootstrap admin password.
  sops.secrets.cms_admin_password = {
    owner = "directus";
  };

  # Rendered env file injected as Directus EnvironmentFile.
  sops.templates."directus-env" = {
    content = ''
      SECRET=${config.sops.placeholder.directus_secret}
      ADMIN_PASSWORD=${config.sops.placeholder.cms_admin_password}
    '';
    owner = "directus";
  };

  # Rendered env file for Caddy's EnvironmentFile, avoids exposing the token
  # in the process environment of other services.
  sops.templates."caddy-cloudflare-env" = {
    content = "CF_API_TOKEN=${config.sops.placeholder.cloudflare_api_token}";
    owner = "caddy";
  };

  # Rendered env file for NetworkManager ensureProfiles variable substitution.
  sops.templates."wifi-env".content = "WIFI_PSK=${config.sops.placeholder.wifi_psk}";

}
