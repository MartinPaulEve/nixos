function dnstls --description "Switch systemd-resolved DNS-over-TLS: strict <-> opportunistic (e.g. for captive portals)"
    # The declarative default (modules/nixos/networking.nix) is strict DoT, which
    # fails closed. Captive portals block encrypted DNS (port 853), so you can't
    # reach the login page until DoT can fall back to plaintext. This toggles the
    # GLOBAL DNSOverTLS setting via a systemd-resolved drop-in and restarts the
    # service. The drop-in lives in /run, so it is transient: a reboot (or
    # `dnstls strict`) restores the strict declarative default.
    set -l dropin /run/systemd/resolved.conf.d/50-dnstls-override.conf

    switch "$argv[1]"
        case opportunistic loose
            sudo mkdir -p (dirname $dropin); or return 1
            printf '[Resolve]\nDNSOverTLS=opportunistic\n' | sudo tee $dropin >/dev/null; or return 1
            sudo systemctl restart systemd-resolved; or return 1
            echo "DNS-over-TLS: opportunistic — falls back to plaintext when blocked (captive portals)."
            echo "Transient: reverts to strict on reboot, or run 'dnstls strict'."
        case strict yes
            sudo rm -f $dropin; or return 1
            sudo systemctl restart systemd-resolved; or return 1
            echo "DNS-over-TLS: strict — encrypted only (declarative default)."
        case status ''
            if test -f $dropin
                echo "DNS-over-TLS: opportunistic (temporary override active)"
            else
                echo "DNS-over-TLS: strict (default)"
            end
        case '*'
            echo "usage: dnstls [strict|opportunistic|status]" >&2
            return 1
    end
end
