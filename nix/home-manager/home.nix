{ config, pkgs, ... }:

{
  home.username = "martint";
  home.homeDirectory = "/home/martint";

  home.stateVersion = "24.05";

  home.packages = [
    pkgs.bat
    pkgs.btop
    pkgs.evince
    pkgs.eza
    pkgs.fd
    pkgs.feh
    pkgs.pavucontrol
    pkgs.ripgrep
    pkgs.rustup
    pkgs.tree
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

export N_PREFIX="$HOME/n"
[[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"
if [ -e '$HOME/.tokens' ]; then
  . $HOME/.tokens
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

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd.enable = true;
    extraConfig = ''

exec = foot --server
$terminal = foot
$mainMod = SUPER
input {
  kb_layout = losipai
  kb_options = caps:escape_shifted_capslock
  follow_mouse = 1
}
misc {
  force_default_wallpaper = 1
  disable_hyprland_logo = false
}
bind = $mainMod, Return, exec, kitty,
bind = ALT, Return, exec, kitty,
bind = $mainMod SHIFT, Return, exec, kitty,
bind = $mainMod, T, exec, footclient,
bind = $mainMod SHIFT, C, killactive,
bind = $mainMod SHIFT, Q, exit,
bind = $mainMod, F, fullscreen
bind = $mainMod, V, togglefloating,
bind = $mainMod, P, pseudo, # dwindle
bind = $mainMod, J, togglesplit, # dwindle
bind = $mainMod, R, exec, footclient --title=launcher bash -c 'compgen -c | sort -u | fzf --no-extended --reverse --border=sharp --color=16 --print-query | tail -1 | xargs -0 -r hyprctl dispatch exec'

# Move focus with mainMod + arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Move tiles with mainMod SHIFT + arrow keys
bind = $mainMod SHIFT, left, movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up, movewindow, u
bind = $mainMod SHIFT, down, movewindow, d

# Switch workspaces with mainMod + [0-9]
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to a workspace with mainMod + SHIFT + [0-9]
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

# Example special workspace (scratchpad)
bind = $mainMod, S, togglespecialworkspace, magic
bind = $mainMod SHIFT, S, movetoworkspace, special:magic

# Scroll through existing workspaces with mainMod + scroll
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1

# Move/resize windows with mainMod + LMB/RMB and dragging
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow


bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindl = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindel = ,XF86MonBrightnessDown, exec, brightnessctl -q set 5%-
bindel = ,XF86MonBrightnessUp, exec, brightnessctl -q set +5%
      '';
  };
}
