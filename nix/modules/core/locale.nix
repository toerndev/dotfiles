{ config, pkgs, pkgs-unstable, ... }:
{
  console.useXkbConfig = true;
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

  environment.systemPackages = with pkgs; [
    bash
    bat
    bc
    curl
    gcc
    git
    github-cli
    pkgs-unstable.neovim
  ];

  environment.variables.EDITOR = "nvim";
  environment.variables.COLORTERM = "truecolor";
  environment.shellAliases = {
    gs = "git status";
    vim = "nvim";
  };
}
