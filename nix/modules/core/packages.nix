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
    lsof
    psmisc
    python3
    ripgrep
    sqlite
    usbutils
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  environment.variables.COLORTERM = "truecolor";
}
