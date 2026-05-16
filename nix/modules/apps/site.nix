{ config, pkgs, ... }:
let
  # Corepack resolves the Yarn Berry version from packageManager field.
  # Needs a writable COREPACK_HOME; CacheDirectory provides /var/cache/site-builder.
  yarn-wrapper = pkgs.writeShellScriptBin "yarn" ''
    export COREPACK_HOME=/var/cache/site-builder/corepack
    exec ${pkgs.nodejs}/bin/corepack yarn "$@"
  '';
in
{
  users.users.site-builder = {
    isSystemUser = true;
    group = "site-builder";
    description = "Webhook-triggered site builder";
  };
  users.groups.site-builder = {};

  # /srv/datasvard-cms: code + node_modules. losipai owns (write); site-builder group reads.
  systemd.tmpfiles.rules = [
    "d /srv/datasvard-cms 02750 losipai site-builder -"
  ];

  systemd.services.site-webhook = {
    description = "Datasvard site webhook receiver";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    path = [ pkgs.nodejs yarn-wrapper ];

    environment = {
      WEBHOOK_HOST = "127.0.0.1";
      WEBHOOK_PORT = "9055";
      DEBOUNCE_MS = "10000";
      # Account ID is not sensitive; API token comes from the sops EnvironmentFile.
      CLOUDFLARE_ACCOUNT_ID = "81eb5f134ec044f637571e21ce194731";
      # Wrangler writes credentials/config here; HOME is unavailable with ProtectHome.
      WRANGLER_HOME = "/var/cache/site-builder/wrangler";
    };

    serviceConfig = {
      User = "site-builder";
      Group = "site-builder";
      WorkingDirectory = "/srv/datasvard-cms";

      ExecStart = "${pkgs.nodejs}/bin/node --experimental-strip-types /srv/datasvard-cms/webhook/src/server.ts";

      # CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN from sops template.
      EnvironmentFile = config.sops.templates."site-builder-env".path;

      # /var/cache/site-builder: corepack + wrangler caches.
      CacheDirectory = "site-builder";
      # /srv/datasvard-cms needs write access for build output (site/build/).
      ReadWritePaths = [ "/srv/datasvard-cms" ];

      Restart = "on-failure";
      RestartSec = "5s";

      # Hardening — no MemoryDenyWriteExecute: Node.js V8 JIT requires W+X pages.
      ProtectSystem = "strict";
      ProtectHome = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ];
      PrivateTmp = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
    };
  };
}
