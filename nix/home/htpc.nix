{ config, pkgs, lib, inputs, ... }:

{
  home.username = "htpc-user";
  home.homeDirectory = "/home/htpc";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # Kodi profile configuration
  home.file.".kodi/userdata/profiles.xml".text = ''
    <profiles>
      <lastloaded>0</lastloaded>
      <useloginscreen>true</useloginscreen>
      <autologin>1</autologin>
      <nextIdProfile>-1</nextIdProfile>
      <profile>
        <id>0</id>
        <name>Barn</name>
        <directory>special://masterprofile/profiles/Barn/</directory>
        <thumbnail></thumbnail>
        <hasdatabases>true</hasdatabases>
        <canwritedatabases>false</canwritedatabases>
        <hassources>true</hassources>
        <canwritesources>false</canwritesources>
        <lockaddonmanager>true</lockaddonmanager>
        <locksettings>0</locksettings>
        <lockfiles>false</lockfiles>
        <lockmusic>false</lockmusic>
        <lockvideo>false</lockvideo>
        <lockpictures>false</lockpictures>
        <lockprograms>true</lockprograms>
        <lockmode>0</lockmode>
        <lockcode></lockcode>
      </profile>
    </profiles>
  '';

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "libretro-snes9x"
  ];

  home.packages = with pkgs; [
    (retroarch.override {
      cores = with libretro; [
        snes9x
      ];
    })
  ];

#   home.file.".config/retroarch/retroarch.cfg".text = ''
#     gamemode_enable = "false";
#   '';
#
#   home.activation.retroarchSetup = lib.hm.dag.entryAfter ["writeBoundary"] ''
#     mkdir -p ~/.config/retroarch/{states,saves}
#
#     if [ ! -f ~/.config/retroarch/retroarch.cfg ]; then
#       cat > ~/.config/retroarch/retroarch.cfg << 'EOF'
# gamemode_enable = "false"
# input_driver = "udev"
# input_joypad_driver = "udev"
# savestate_auto_save = "true"
# savestate_auto_load = "true"
# savestate_directory = "~/.config/retroarch/states"
# savefile_directory = "~/.config/retroarch/saves"
# input_autodetect_enable = "true"
# EOF
#     fi
#   '';
}
