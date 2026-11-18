{ lib, ... }:
{
  options.services.nginx.virtualHosts = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        config = {
          http2 = lib.mkForce false;
          http3 = lib.mkForce false;
          quic = lib.mkForce false;
        };
      }
    );
  };
}
