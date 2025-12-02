{
  config,
  pkgs,
  ...
}:
{
  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    forceSSL = true;
    enableACME = true;
  };

  sops.secrets.nextcloud = {
    sopsFile = ../secrets/nextcloud.txt;
    format = "binary";
  };
  sops.secrets.nextcloud-admin-pass = {
    sopsFile = ../secrets/nextcloud-admin-pass.txt;
    format = "binary";
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32.overrideAttrs (prev: {
      # Patch is based on this issue: https://github.com/nextcloud/server/issues/14391
      patches = (prev.patches or [ ]) ++ [ ../0001-fix-azure-blob-storage-upload.patch ];
    });
    extraApps = {
      inherit (pkgs.nextcloud32Packages.apps) forms onlyoffice;
    };
    hostName = "nextcloud.otanix.fi";
    https = true;
    config = {
      adminuser = "board";
      adminpassFile = config.sops.secrets.nextcloud-admin-pass.path;
      dbtype = "pgsql";
    };
    maxUploadSize = "5G";

    nginx.enableFastcgiRequestBuffering = true;

    settings = {
      mail_from_address = "system";
      mail_domain = "nextcloud.otanix.fi";
      mail_smtpmode = "smtp";
      mail_sendmailmode = "smtp";
      mail_smtpauthtype = "PLAIN";
      mail_smtpauth = true;
      mail_smtphost = "mail.portfo.rs";
      mail_smtpport = 465;
      mail_smtpsecure = "ssl";
      mail_smtpname = "system@nextcloud.otanix.fi";
    };

    database.createLocally = true;

    secretFile = config.sops.secrets.nextcloud.path;
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "board@o" + "tanix.fi";
  };
}
