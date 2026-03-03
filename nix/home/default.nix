{ config, pkgs, pkgs-unstable, lib, inputs, systemConfig, ... }:

{
  home.username = "losipai";
  home.homeDirectory = "/home/losipai";
  home.stateVersion = systemConfig.stateVersion;

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    pkgs-unstable.claude-code
  ];
}
