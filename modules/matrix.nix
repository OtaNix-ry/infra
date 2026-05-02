{
  config,
  pkgs,
  ...
}:
let
  fqdn = "matrix.otanix.fi";
  port = 3987;
  synapse-admin' = pkgs.synapse-admin-etkecc.withConfig {
    restrictBaseUrl = "https://${fqdn}";
  };
in
{
  sops.secrets.matrix-shared-secret = {
    sopsFile = ../secrets/matrix-shared-secret.txt;
    format = "binary";
    owner = "matrix-synapse";
  };
  services = {
    postgresql = {
      enable = true;
      initialScript = pkgs.writeText "pg-init" ''
        CREATE ROLE "matrix-synapse" WITH LOGIN;
        CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
          TEMPLATE template0
          LC_COLLATE = "C"
          LC_CTYPE = "C";
      '';
    };
    matrix-synapse = {
      enable = true;
      settings = {
        server_name = "otanix.fi";
        public_baseurl = "https://${fqdn}";

        enable_registration = true;
        registration_requires_token = true;
        registration_shared_secret_path = config.sops.secrets.matrix-shared-secret.path;
        allow_public_rooms_over_federation = true;
        room_list_publication_rules = [
          {
            user_id = "@langsjo:otanix.fi";
            action = "allow";
          }
        ];

        listeners = [
          {
            inherit port;
            bind_addresses = [ "127.0.0.1" ];
            type = "http";
            tls = false;
            x_forwarded = true;
            resources = [
              {
                names = [
                  "client"
                  "federation"
                ];
                compress = true;
              }
            ];
          }
        ];
      };
    };
    nginx = {
      enable = true;
      # .well-known/matrix handled in OtaNix-ry/otanix.fi
      virtualHosts.${fqdn} = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/".extraConfig = "return 404;";
          "/_matrix".proxyPass = "http://127.0.0.1:${toString port}";
          "/_synapse/client".proxyPass = "http://127.0.0.1:${toString port}";

          "/_synapse/admin".proxyPass = "http://127.0.0.1:${toString port}";
          "/admin/" = {
            alias = "${synapse-admin'}/";
            tryFiles = "$uri $uri/ /admin/index.html";
            index = "index.html";
          };
          "/admin".extraConfig = "return 301 /admin/;";
        };
      };
    };
  };
}
