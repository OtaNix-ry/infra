{
  config,
  lib,
  pkgs,
  ...
}:
let
  nextcloudHost = "nextcloud.otanix.fi";
  onlyofficeHost = "office.otanix.fi";
  onlyofficeJwtSopsFile = ../secrets/onlyoffice-jwt.txt;
  onlyofficeNonceSopsFile = ../secrets/onlyoffice-nginx-nonce.txt;
in
{
  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    forceSSL = true;
    enableACME = true;
  };
  services.nginx.virtualHosts.${onlyofficeHost} = {
    forceSSL = true;
    enableACME = true;
  };

  assertions = [
    {
      assertion = builtins.pathExists onlyofficeJwtSopsFile;
      message = "Missing SOPS secret file: secrets/onlyoffice-jwt.txt";
    }
    {
      assertion = builtins.pathExists onlyofficeNonceSopsFile;
      message = "Missing SOPS secret file: secrets/onlyoffice-nginx-nonce.txt";
    }
  ];

  sops.secrets.nextcloud = {
    sopsFile = ../secrets/nextcloud.txt;
    format = "binary";
  };
  sops.secrets.nextcloud-admin-pass = {
    sopsFile = ../secrets/nextcloud-admin-pass.txt;
    format = "binary";
  };
  sops.secrets.onlyoffice-jwt = {
    sopsFile = onlyofficeJwtSopsFile;
    format = "binary";
    group = "onlyoffice";
    mode = "0440";
  };
  sops.secrets.onlyoffice-nginx-nonce = {
    sopsFile = onlyofficeNonceSopsFile;
    format = "binary";
    group = "onlyoffice";
    mode = "0440";
  };

  services.onlyoffice = {
    enable = true;
    hostname = onlyofficeHost;
    jwtSecretFile = config.sops.secrets.onlyoffice-jwt.path;
    securityNonceFile = config.sops.secrets.onlyoffice-nginx-nonce.path;
  };

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud32.overrideAttrs (prev: {
      # Patch is based on this issue: https://github.com/nextcloud/server/issues/14391
      patches = (prev.patches or [ ]) ++ [ ../0001-fix-azure-blob-storage-upload.patch ];
    });
    extraApps = {
      forms = pkgs.nextcloud32Packages.apps.forms.overrideAttrs (prev: {
        patches = (prev.patches or [ ]) ++ [ ../0002-fix-forms-linking-with-objectstore.patch ];
      });
      inherit (pkgs.nextcloud32Packages.apps) onlyoffice;
    };
    hostName = nextcloudHost;
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
      mail_smtpname = "system@${nextcloudHost}";
      allow_local_remote_servers = true;

      # ONLYOFFICE reads system fallback config from the nested "onlyoffice"
      # section in config.php (not top-level keys).
      onlyoffice = {
        DocumentServerUrl = "https://${onlyofficeHost}/";
        DocumentServerInternalUrl = "http://127.0.0.1:8000/";
        StorageUrl = "https://${nextcloudHost}/";
        jwt_header = "Authorization";
        verify_peer_off = true;
      };
    };

    phpOptions = {
      # This forces PHP to flush data to Nginx immediately, preventing
      # it from accumulating the file in memory.
      "output_buffering" = "0";
      "max_execution_time" = "300";
    };

    database.createLocally = true;

    secretFile = config.sops.secrets.nextcloud.path;
  };

  # Avoid public-IP hairpinning for server-side callbacks/checks on the same VM.
  networking.hosts."127.0.0.1" = [
    nextcloudHost
    onlyofficeHost
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = "board@o" + "tanix.fi";
  };
}
