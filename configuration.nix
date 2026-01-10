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
    ./modules/jitsi.nix
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
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC0xmxXd5K3pgTCrwMmKwILyOJb9KD9PWvQfbzncPUJLpb7XSoPS8Iwnrn9+VdXHFLKQvQBI33Bk+l7Yj0AQJX1/wOoMnNmfxq/fzKCCSvBocu/x8SJVyqRCksLtHTrf0xfcFM9YSpMouIrpWqXGEz1qDt7j8v4nYmp1NrS8Sw2IW99m7RMtzPjB49OzRe1sggqCpDfaqysAjm7VjnLuib8CdrhaGnQ3z7Jl8Dt2IWXyfk/SVZAqJzjcBF9aVnYfskn4Kes0D9bO/+dTHoWmVqYokjOYKMvx+o8s6Ydk3S2Ej+/RMEPTRoTez0cXvjXrpQG9Ke0PMPt3EjvvdpxmWbL6/+OZoQ1dxOpqtc5S6hQ9TLR1j6FrhvvJRf5mHPr8DV+a1Sg/ptiZ+8RK+WDN0RlIsLO+GnKS0gyzzqfrP41lDt1jSD2JTnAv2ACT25TANGIiYU9GNHsyuph1NEeTJICeyIOqkB8+ABKBKRH5JjdOROgwxcomEdBcuXGcgP8VbQaE6hWA30AVOGt5klRFA3bE4zhdLNnp7Hn26A43gBgbZp33xVhbqoNyW+qWb32A7Nd5KWMqa0p3ZllYsNRSOgOhqciNzQjsfolYXP8vUG3sCWkwtZBk4A5Cvm+Jhd0v+SFSm9rDyosbc7v0MN6rgBxZIYfYlMLvaMiyPWuxNZ6wQ=="
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
