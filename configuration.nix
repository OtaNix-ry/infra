{
  modulesPath,
  lib,
  inputs,
  ...
}:
{
  imports = [
    (modulesPath + "/virtualisation/azure-common.nix")
    ./modules/deployment.nix
    ./modules/nextcloud.nix
    # blocked by Azure
    #./modules/mail.nix
    ./modules/sops.nix
  ];

  # 1. DISK LAYOUT (UEFI / GPT)
  # This tells the installer to wipe the disk and create correct partitions
  disko.devices.disk.main = {
    device = "/dev/sda"; # Usually sda on B-series, use nvme0n1 if L-series
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          type = "EF00";
          size = "500M";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  # 2. BOOTLOADER (Systemd-boot for UEFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 3. SSH ACCESS
  services.openssh.enable = true;
  services.fail2ban.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    # PASTE YOUR PUBLIC KEY STRING HERE (e.g. "ssh-rsa AAA...")
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiDxF/PZcYfX6N3CQOdQdW0PTPN7tgmwL6RPFDBlJURsxiTlmlRygjMVjrnxbIN9KGIP2p3hUKxensm0ftbl3fvdBG3nUnreGZAUQ7prSrli3tv+WITPFdONtDqcrMlYXbBy51/kFLUQMV7wBYurM/4bW/BOXtNZdk8/dLyCqAr1ynZmXFFHEB3APtlxaLlsyHEER5Nj7WDlxpFUxOqzasPg8MMGKQeN+d2TbUq1s0YDVwmk4F+Zqfj0H9AAYYt4zkiKbCkzTrJXk9snBPAyUot8jkAjZW5nu7quVoiHvWY3335iaa4o2JWDkm6/QEXYzKIbi865jOr3A5DRFytNFQJ7nmXfSNWAJmblSlatlszQLwmTLP5wkV+3zbRHv7WuvWivR76Xy0uyK331UvqrRbNha+EbVoWP5DyFnichBH7B/IgHkLHQJIuYiQBZ2ZwTuVpEoxyCUyl9acDtmUZvuomTAEjLRQElnhRo8iyDf92dl19Q9dG/1RWqLXUEDVBcLrlk89aEnIk7DuwvmVWzWM+On9S8ojH04TgRJM5ZkbQLAIqW5AkLqY6CP5Gzknsh7F4fl5Mq0FZlCOtFzxR+YgIn4IGndonm8/iqDQjJNOWVysFdNRPisPSR5AO5TiuxZSOcCuRkS56cZTHKjdqZS8CxiCfs2ZPlzMnzKJSNDXxQ=="
  ];

  # 4. FIX FOR AZURE SERIAL CONSOLE
  boot.kernelParams = [ "console=ttyS0" ];

  # This prevents it from trying to run random scripts found in Azure metadata.
  services.cloud-init.enable = lib.mkForce false;

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    registry.nixpkgs.flake = inputs.nixpkgs;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
  };

  system.stateVersion = "25.05";
}
