{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bash
    bat
    bc
    curl
    fd
    gcc
    git
    github-cli
    gnumake
    gawk
    gnused
    jq
    python3
    ripgrep
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  environment.variables.COLORTERM = "truecolor";
}
