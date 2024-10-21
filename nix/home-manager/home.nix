{ config, pkgs, ... }:

{
  home.username = "martint";
  home.homeDirectory = "/home/martint";
  nixpkgs.config.allowUnfree = true;

  home.stateVersion = "24.05";

  home.packages = [
    pkgs.awscli2
    pkgs.bat
    pkgs.btop
    pkgs.evince
    pkgs.eza
    pkgs.fd
    pkgs.feh
    pkgs.glow
    pkgs.hyprpaper
    pkgs.pavucontrol
    pkgs.pavucontrol
    pkgs.python312Packages.cfn-lint
    pkgs.ripgrep
    pkgs.ripgrep
    pkgs.rustup
    pkgs.rustup
    pkgs.tree
    pkgs.tree
    pkgs.up
    (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })
    (pkgs.writeShellScriptBin "my-hello" ''
      echo "Hello, ${config.home.username}!"
    '')
  ];

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    shellAliases = {
      l = "eza -ahl";
      ll = "eza -ahl";
      ls = "eza";
      ip = "ip --color=auto";
      gs = "git status";
      gd = "git diff";
      gdc = "git diff --cached";
      did = "vim +'normal Go' +'r!date' ~/did.txt";
      vim = "nvim";
    };
    initExtra = ''
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
bindkey '^ ' autosuggest-accept
AGKOZAK_CMD_EXEC_TIME=5
AGKOZAK_COLORS_CMD_EXEC_TIME='yellow'
AGKOZAK_COLORS_PROMPT_CHAR='magenta'
AGKOZAK_CUSTOM_SYMBOLS=( '⇣⇡' '⇣' '⇡' '+' 'x' '!' '>' '?' )
AGKOZAK_MULTILINE=0
AGKOZAK_PROMPT_CHAR=( ❯ ❯ ❮ )

# git: don't paginate if less than a page
export LESS="-F -X $LESS"

export N_PREFIX="$HOME/n"
[[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"
if [ -e '$HOME/.env' ]; then
  . $HOME/.env
fi
'';
    plugins = with pkgs; [
      {
        name = "agkozak-zsh-prompt";
        src = fetchFromGitHub {
          owner = "agkozak";
          repo = "agkozak-zsh-prompt";
          rev = "v3.11.4";
          sha256 = "1n50c0hfz1spasnpc7f3rnqdy2y5py871fmas9vgbscjjqhlnbql";
        };
        file = "agkozak-zsh-prompt.plugin.zsh";
      }
    ];
    history = {
      ignoreAllDups = true;
      # path = "${config.xdg.dataHome}/zsh/history";
      save = 200000;
      size = 200000;
      share = true;
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;

  programs.gpg.enable = true;

  programs.foot = {
    enable = true; 
    server.enable = true;
  };
}
