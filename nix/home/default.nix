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
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="$HOME/.npm-global/bin:$PATH"
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
    nodejs_24
    python3
    pkgs-unstable.claude-code
  ];
}
