{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

{
  home.username = "losipai";
  home.homeDirectory = "/home/losipai";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    initExtra = ''
      export ANTHROPIC_API_KEY=$(cat ~/.anthropic_key)
    '';
  };

  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      addKeysToAgent = "1h";
    };
  };

  home.packages = with pkgs; [
    pkgs-unstable.claude-code
  ];
}
