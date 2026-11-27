# The immurok module (modules/nixos/immurok) on a running system: a NixOS
# test that boots a small VM with the module in it and no fingerprint key
# anywhere near, which is the case that must never go wrong — sudo has to
# fall through to the password exactly as it did before.
#
# Unlike tests/hosts.nix this builds and boots something (it needs KVM), so
# it is run by hand, after a version bump or a change to the module:
#
#   nix build --impure --no-link -L -f tests/immurok_vm.nix
#
# The key itself cannot be tested here: a fingerprint needs a finger.
let
  flake = builtins.getFlake (toString ./..);
  system = builtins.currentSystem;
  pkgs = flake.inputs.nixpkgs.legacyPackages.${system};
in
pkgs.testers.runNixOSTest {
  name = "immurok";

  nodes.machine = { ... }: {
    imports = [ ../modules/nixos/immurok ];

    security.polkit.enable = true;
    # The YubiKey factor the fingerprint is ordered against (security.nix).
    security.pam.u2f = {
      enable = true;
      control = "sufficient";
    };

    users.users.alice = {
      isNormalUser = true;
      password = "correct";
      extraGroups = [ "wheel" ];
    };
  };

  testScript = ''
    def sudo_with(password):
        return f"su - alice -c 'echo {password} | timeout 20 sudo -S -k true'"

    machine.wait_for_unit("multi-user.target")

    with subtest("the daemon runs under its own account"):
        machine.wait_for_unit("immurok-daemon.service")
        machine.wait_until_succeeds("test -S /run/immurok/pam.sock")
        assert machine.succeed("systemctl show immurok-daemon -p User --value").strip() == "immurok"
        # The PAM module trusts the socket only in a directory like this.
        assert machine.succeed("stat -c '%U %a' /run/immurok").strip() == "immurok 755"
        assert machine.succeed("stat -c '%U %a' /var/lib/immurok").strip() == "immurok 700"

    with subtest("an ordinary user can reach the daemon"):
        machine.succeed("su - alice -c 'immurok-cli status'")

    with subtest("without a key, sudo asks for the password"):
        machine.succeed(sudo_with("correct"))
        machine.fail(sudo_with("wrong"))

    with subtest("the same with the daemon stopped"):
        machine.succeed("systemctl stop immurok-daemon")
        machine.succeed(sudo_with("correct"))
        machine.fail(sudo_with("wrong"))
        machine.succeed("systemctl start immurok-daemon")

    with subtest("the session agent runs in a person's session"):
        machine.succeed("loginctl enable-linger alice")
        machine.wait_until_succeeds(
            "systemctl --user --machine=alice@.host is-active immurok-session-agent.service"
        )

    with subtest("the app's PAM helper reports and changes nothing"):
        helper = "$(dirname $(readlink -f $(command -v immurok-cli)))/immurok-pam-helper"
        before = machine.succeed("cat /etc/pam.d/sudo /etc/pam.d/polkit-1")
        assert machine.succeed(f"{helper} add sudo polkit-1").split() == [
            "OK:ALREADY_PRESENT(sudo)",
            "OK:ALREADY_PRESENT(polkit-1)",
        ]
        assert machine.succeed(f"{helper} remove sudo").strip() == "ERROR:MANAGED_BY_NIXOS(sudo)"
        assert machine.succeed("cat /etc/pam.d/sudo /etc/pam.d/polkit-1") == before
  '';
}
