# Networking: NetworkManager, firewall, Tailscale, and OpenVPN.
{ config, ... }:

{
  # Enable networking via NetworkManager.
  networking.networkmanager.enable = true;

  # Tailscale mesh VPN.
  services.tailscale.enable = true;

  # OpenVPN 3 client (used for the hcommons VPN).
  programs.openvpn3.enable = true;

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
