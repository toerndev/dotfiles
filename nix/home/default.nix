{ config, pkgs, pkgs-unstable, lib, inputs, ... }:

{
  home.username = "losipai";
  home.homeDirectory = "/home/losipai";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    initExtra = ''
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      export PATH="$HOME/.npm-global/bin:$PATH"
    '';
  };

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    historyLimit = 50000;
    escapeTime = 0;
    baseIndex = 1;
    prefix = "C-q";
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
    nodejs_22
    pkgs-unstable.claude-code
    python3
    ssh-to-age
    sops
  ];
}
