{ config, pkgs, systemConfig, ... }:

{
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 20;
    editor = false;
  };
  boot.loader.timeout = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  console.useXkbConfig = true;
  # environment.etc."xkb/symbols/custom".source = ./xkb/custom-symbols;
  services.xserver.xkb = {
    extraLayouts.custom = {
      description = "Swedish (custom)";
      languages = [ "se" ];
      symbolsFile = ./xkb/custom-symbols;
    };
    layout = "custom";
    options = "caps:escape";
  };

  time.timeZone = "Europe/Stockholm";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "sv_SE.UTF-8";
    LC_IDENTIFICATION = "sv_SE.UTF-8";
    LC_MEASUREMENT = "sv_SE.UTF-8";
    LC_MONETARY = "sv_SE.UTF-8";
    LC_NAME = "sv_SE.UTF-8";
    LC_NUMERIC = "sv_SE.UTF-8";
    LC_PAPER = "sv_SE.UTF-8";
    LC_TELEPHONE = "sv_SE.UTF-8";
    LC_TIME = "sv_SE.UTF-8";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = systemConfig.stateVersion;

  environment.systemPackages = with pkgs; [
    bash
    bat
    bc
    curl
    git
    github-cli
    neovim
  ];

  environment.variables.EDITOR = "nvim";
  environment.shellAliases = {
    gs = "git status";
    vim = "nvim";
  };
}
