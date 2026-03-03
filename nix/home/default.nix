{ config, pkgs, lib, inputs, systemConfig, ... }:

{
  home.username = "losipai";
  home.homeDirectory = "/home/losipai";
  home.stateVersion = systemConfig.stateVersion;

  programs.home-manager.enable = true;
}
