{ config, ... }:
{
  sops.secrets.email-hashed-password = {
    sopsFile = ../secrets/email-hashed-password.txt;
    format = "binary";
  };

  mailserver = {
    enable = true;
    stateVersion = 3;
    fqdn = "nextcloud.otanix.fi";
    domains = [ "nextcloud.otanix.fi" ];

    loginAccounts = {
      "system@nextcloud.otanix.fi" = {
        sendOnly = true;
        hashedPasswordFile = config.sops.secrets.email-hashed-password.path;
      };
    };

    enableSubmission = true;

    certificateScheme = "acme-nginx";
  };

  networking.firewall.allowedTCPPorts = [ 465 ];
}
