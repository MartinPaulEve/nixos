# Parallels Tools Service
{ pkgs, ... }:

{
  # Aggressively shutdown Parallels Tools, which otherwise hangs shutdown
  xdg.configFile."systemd/user/prlcc.service.d/override.conf".text = ''
    [Service]
	TimeoutStopSec=2s
  '';
}
