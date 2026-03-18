{ config, ... }:
{
  sops.defaultSopsFile = ../../secrets/secrets.yaml;

  # Decrypt using the host's SSH ed25519 key (no separate age key to manage)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets.wireguard_private_key = {};

  sops.secrets.cloudflare_api_token = {};

  sops.secrets.ddclient_password = {};

  # Rendered env file for Caddy's EnvironmentFile — avoids exposing the token
  # in the process environment of other services.
  sops.templates."caddy-cloudflare-env" = {
    content = "CF_API_TOKEN=${config.sops.placeholder.cloudflare_api_token}";
    owner = "caddy";
  };

}
