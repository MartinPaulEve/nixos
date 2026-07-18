# Networking: NetworkManager, firewall, Tailscale, and OpenVPN.
{ config, lib, ... }:

let
  # NextDNS device identifier: this host's name prepended to the NextDNS
  # profile domain (profile 715a8c), per NextDNS's "prepend the name" guidance,
  # so queries from this machine are tagged as "nixos" in the dashboard.
  # networking.hostName is already limited to NextDNS-safe characters
  # (a–z, 0–9, -), so no sanitisation or `--` space-escaping is needed.
  nextdnsEndpoint = "${config.networking.hostName}-715a8c.dns.nextdns.io";
in
{
  # Enable networking via NetworkManager.
  networking.networkmanager.enable = true;

  # Tailscale mesh VPN.
  services.tailscale.enable = true;

  # OpenVPN 3 client (used for the hcommons VPN).
  programs.openvpn3.enable = true;
  
  # DNS via NextDNS over TLS. systemd-resolved is also required by openvpn3.
  # Each server address carries the NextDNS endpoint as its TLS SNI (after `#`),
  # which is how NextDNS applies the profile and this device's identifier.
  # DNSOverTLS = "true" is strict and fails closed if DoT is unavailable; the
  # `dnstls` fish function flips it to opportunistic at runtime for captive
  # portals (see home/martin/functions/dnstls.fish).
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "45.90.28.0#${nextdnsEndpoint}"
        "2a07:a8c0::#${nextdnsEndpoint}"
        "45.90.30.0#${nextdnsEndpoint}"
        "2a07:a8c1::#${nextdnsEndpoint}"
      ];
      DNSOverTLS = "true";
    };
  };

  # Make resolved's global NextDNS servers authoritative for general lookups,
  # instead of letting NetworkManager push DHCP-provided DNS as the default
  # resolver (which would bypass NextDNS). mkForce overrides the resolved module,
  # which otherwise sets this to "systemd-resolved". Tailscale and openvpn3
  # register their split-DNS domains with resolved directly, so VPN name
  # resolution still works.
  networking.networkmanager.dns = lib.mkForce "none";

  # Firewall, backed by nftables.
  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    # Always allow traffic from the Tailscale network.
    trustedInterfaces = [ config.services.tailscale.interfaceName ];
    # Allow the Tailscale UDP port through the firewall.
    allowedUDPPorts = [ config.services.tailscale.port ];
  };

  # Force tailscaled to use nftables directly, avoiding the iptables-compat
  # translation layer on nftables-only systems.
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  # Don't block boot waiting for the network to come online (faster boot with VPNs).
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;
}
