{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

{
  home.username = "losipai";
  home.homeDirectory = "/home/losipai";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    pkgs-unstable.claude-code
  ];
}
