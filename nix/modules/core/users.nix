{ config, pkgs, ... }:
{
  # Required for deploy-rs: activation scripts run as root via sudo from a
  # non-interactive SSH session. Password prompt would block the deploy.
  # On NixOS, wheel already implies near-root access, so this doesn't
  # meaningfully change the threat model for a single-admin machine.
  security.sudo.wheelNeedsPassword = false;

  users.users.losipai = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvmccLuoKuu0hxlj+sGean56+UzXx/cXwq3V14F89jh personal"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDY7XIevkx65n2Ywn2XCGJtfeqAHQ0ICEn00iWDJmIr5C/2sglltkWrb30z0+8MrMFTk6kYV8lryWbARHVNkjAvwMjSVtb+9kDq9n5CbANW7uzIL7pOP3yxMcfTtunFACQzFFCrz/DA5a62C8J0nM2W4U/+BqCkskCxJ/xMu3jULzxwEo2xfXKEPXCzlsJY1iw5dPnDGadugge2XaLDUT83IYh7LE9amHWkDxydRU4KEt5dNyvgJAYGgQ+/J5F5vI4yr4FO8JzXCLjC7dSIZ8Vd/2l1m0pQ6tJKFwcXZ1bErDg65tZth6saOq1GgCYa7SJT6uWIE/D/fja1JlpUrM2m9Stl93mVusWhT+GFRGUDPmhE+E7x4HwSj02EYV7u8zPlwh/k6uyfqLHKfakCCpMGrdz7mLk8Wl6K+jUPqVfY5xCtD+jly/G9b94oZboF7Q4JaBDqLRW/LzeXSXXEWHOVHsF2SHbs8LLBxwf+hOLvwyFVw5XNqnq2GRDYhOBsTL0= work"
    ];
  };
}
