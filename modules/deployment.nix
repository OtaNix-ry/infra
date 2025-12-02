{
  pkgs,
  lib,
  config,
  ...
}:
let
  rebuild-from-infra = pkgs.writeShellScriptBin "rebuild-from-infra" ''
    ${lib.getExe config.system.build.nixos-rebuild} switch --refresh --flake github:OtaNix-ry/infra/"$1"
  '';
in
{
  users = {
    users.deploy = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAcOTUiq2rxkjALXDflJlB78tFD/dwd+BOoBdS4w8ML"
      ];
      group = "deploy";
      packages = [ rebuild-from-infra ];
    };
    groups.deploy = { };
  };

  nix.settings.trusted-users = [ "deploy" ];

  security.sudo.extraRules = [
    {
      users = [ "deploy" ];
      commands = [
        {
          command = "${lib.getExe rebuild-from-infra} *";
          options = [
            "SETENV"
            "NOPASSWD"
          ];
        }
      ];
    }
  ];
}
