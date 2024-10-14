  programs.neovim = {
    enable = true;
    enableLSP = true;
    package = pkgs.unstable.neovim-unwrapped;
    vimAlias = true;
    viAlias = true;
    withNodeJs = true;
    withPython3 = true;
    withRuby = false;
  };
