{ config, lib, pkgs, ... }:
# Generic webhook-triggered build/deploy daemon. Single instance, no per-
# project nix configuration. Knows only its own port and debounce; projects
# pass everything else by convention at request time.
#
# Builder source lives alongside this module:
#   ./src/server.ts   — the receiver (plain TS, run by Node directly)
# Install (admin's job, after a fresh deploy or builder code change):
#   mkdir -p /srv/site-builder/src
#   cp <nix-config>/modules/apps/site-builder/src/server.ts /srv/site-builder/src/
# Node 22.12+ strips TS at runtime by default — no flag, no toolchain.
#
# Triggering a build:
#   POST http://127.0.0.1:<port>/<project-key>
#   → runs `bash scripts/build-and-deploy.sh` in /srv/<project-key>/
# The project owns its own script, its own .env, its own deploy logic.
# The builder owns: per-key debounce, sandboxing, logging.
#
# Adding a new project requires zero nix changes:
#   1. Place project code at /srv/<key>/ (chown to site-builder group, mode 02750).
#   2. Provide /srv/<key>/scripts/build-and-deploy.sh and its dependencies.
#   3. Point the source's webhook at http://127.0.0.1:<port>/<key>.
let
  cfg = config.services.siteBuilder;

  # Corepack needs a writable HOME for yarn. CacheDirectory provides
  # /var/cache/site-builder. Available on PATH so project scripts can call yarn.
  yarn-wrapper = pkgs.writeShellScriptBin "yarn" ''
    export COREPACK_HOME=/var/cache/site-builder/corepack
    exec ${pkgs.nodejs}/bin/corepack yarn "$@"
  '';
in
{
  options.services.siteBuilder = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 9055;
      description = "Loopback port the webhook receiver listens on.";
    };
    debounceMs = lib.mkOption {
      type = lib.types.int;
      default = 10000;
      description = "Per-key wait after the last webhook before the build runs.";
    };
  };

  config = {
    users.users.site-builder = {
      isSystemUser = true;
      group = "site-builder";
      description = "Webhook-triggered site builder";
    };
    users.groups.site-builder = {};

    # /srv/site-builder holds the daemon's own source. Per-project dirs at
    # /srv/<key>/ are created by the admin (not by nix) when setting up a
    # project, with ownership site-builder so the daemon can read/execute.
    systemd.tmpfiles.rules = [
      "d /srv/site-builder 02750 losipai site-builder -"
    ];

    systemd.services.site-builder = {
      description = "Site builder webhook receiver";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      path = [ pkgs.nodejs yarn-wrapper ];

      environment = {
        WEBHOOK_HOST = "127.0.0.1";
        WEBHOOK_PORT = toString cfg.port;
        DEBOUNCE_MS = toString cfg.debounceMs;
      };

      unitConfig.ConditionPathExists = "/srv/site-builder/src/server.ts";

      serviceConfig = {
        User = "site-builder";
        Group = "site-builder";
        WorkingDirectory = "/srv/site-builder";

        ExecStart = "${pkgs.nodejs}/bin/node /srv/site-builder/src/server.ts";

        CacheDirectory = "site-builder";
        # /srv is writable for project build output; unix perms on /srv/<dir>
        # control which projects this daemon can actually touch.
        ReadWritePaths = [ "/srv" ];

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
  };
}
