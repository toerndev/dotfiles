{ config, pkgs, ... }:
{
  users.users.losipai = {
    isNormalUser = true;
    extraGroups = [ "input" "audio" "pipewire" "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvmccLuoKuu0hxlj+sGean56+UzXx/cXwq3V14F89jh personal"
    ];
  };
}
