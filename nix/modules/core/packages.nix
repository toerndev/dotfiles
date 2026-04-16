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
    python3
    ripgrep
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  environment.variables.COLORTERM = "truecolor";
}
