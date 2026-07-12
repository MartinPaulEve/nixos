# Printing and printer discovery.
{ ... }:

{
  # Printing with CUPS.
  services.printing.enable = true;

  # Printer discovery via mDNS/Avahi.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
