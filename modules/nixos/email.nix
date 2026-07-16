# Email client and the Proton Mail bridge.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    thunderbird        # Email / calendar client
    protonmail-bridge  # Proton Mail IMAP/SMTP bridge (headless CLI)
  ];

  # Run the Proton Mail bridge as a per-user service.
  #
  # The GUI build (protonmail-bridge-gui) crashes at login because its GUI
  # component fails to start in this environment. Running the headless bridge
  # non-interactively avoids that: `--noninteractive` skips the interactive
  # prompt and `--no-window` keeps it purely in the background.
  systemd.user.services.protonmail-bridge = {
    description = "Proton Mail bridge";
    after = [ "graphical-session.target" ];
    wantedBy = [ "default.target" ];

    serviceConfig = {
      ExecStart = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --noninteractive --no-window --log-level info";
      Restart = "on-failure";
    };
  };
}
