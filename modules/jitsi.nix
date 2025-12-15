{
  services = {
    jitsi-meet = {
      enable = true;
      prosody.lockdown = true;
      nginx.enable = true;
      hostName = "meet.otanix.fi";
    };
    jitsi-videobridge = {
      openFirewall = true;
      xmppConfigs.localhost.mucNickname = "jvb1";
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # libolm is deprecated
  # https://github.com/NixOS/nixpkgs/pull/334638
  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8792"
  ];
}
