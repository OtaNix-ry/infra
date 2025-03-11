{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/virtualisation/azure-common.nix"
    "${modulesPath}/virtualisation/azure-image.nix"
  ];

  virtualisation.azureImage = {
    vmGeneration = "v2";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.enable = false;

  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  security.sudo.wheelNeedsPassword = false;

  services.nginx = {
    enable = true;
    virtualHosts._ = {
      extraConfig = ''
        return 200 "tervetuloa!"
      '';
    };
  };

  users.users.otanix = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiDxF/PZcYfX6N3CQOdQdW0PTPN7tgmwL6RPFDBlJURsxiTlmlRygjMVjrnxbIN9KGIP2p3hUKxensm0ftbl3fvdBG3nUnreGZAUQ7prSrli3tv+WITPFdONtDqcrMlYXbBy51/kFLUQMV7wBYurM/4bW/BOXtNZdk8/dLyCqAr1ynZmXFFHEB3APtlxaLlsyHEER5Nj7WDlxpFUxOqzasPg8MMGKQeN+d2TbUq1s0YDVwmk4F+Zqfj0H9AAYYt4zkiKbCkzTrJXk9snBPAyUot8jkAjZW5nu7quVoiHvWY3335iaa4o2JWDkm6/QEXYzKIbi865jOr3A5DRFytNFQJ7nmXfSNWAJmblSlatlszQLwmTLP5wkV+3zbRHv7WuvWivR76Xy0uyK331UvqrRbNha+EbVoWP5DyFnichBH7B/IgHkLHQJIuYiQBZ2ZwTuVpEoxyCUyl9acDtmUZvuomTAEjLRQElnhRo8iyDf92dl19Q9dG/1RWqLXUEDVBcLrlk89aEnIk7DuwvmVWzWM+On9S8ojH04TgRJM5ZkbQLAIqW5AkLqY6CP5Gzknsh7F4fl5Mq0FZlCOtFzxR+YgIn4IGndonm8/iqDQjJNOWVysFdNRPisPSR5AO5TiuxZSOcCuRkS56cZTHKjdqZS8CxiCfs2ZPlzMnzKJSNDXxQ=="
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYmcP3Zjh80Bk+ww3ukzq+JHMEIRV3vySevuu6KOt2f"
    ];
  };
}
