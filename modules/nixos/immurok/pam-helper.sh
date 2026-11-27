#!/bin/sh
# immurok-pam-helper, as it is installed on NixOS.
#
# The immurok app runs this through pkexec when "Install" or "Remove" is
# clicked on its PAM page (or from `immurok-cli pam ...`). Upstream's helper
# answers by editing /etc/pam.d, creating the daemon's account and starting
# its unit. On NixOS all of that is the system configuration's business
# (modules/nixos/immurok/default.nix) and /etc/pam.d is read-only, so this
# one changes nothing: it reports what the configuration already provides,
# in the same one-line-per-service form the app reads, and says no to
# anything that would need the configuration changed.
#
# Shell builtins only: pkexec hands over a minimal environment.

action="${1:-}"
[ "$#" -gt 0 ] && shift

case "$action" in
    add | remove) ;;
    *)
        echo "ERROR:MANAGED_BY_NIXOS"
        exit 0
        ;;
esac

# Does the service's PAM stack ask immurok for a fingerprint?
has_immurok() {
    [ -r "/etc/pam.d/$1" ] || return 1
    while IFS= read -r line; do
        case "$line" in
            \#*) ;;
            *pam_immurok.so*) return 0 ;;
        esac
    done < "/etc/pam.d/$1"
    return 1
}

for service in "$@"; do
    case "$service" in
        sudo | polkit-1 | gdm-password) ;;
        *)
            echo "ERROR:INVALID_SERVICE($service)"
            continue
            ;;
    esac

    if has_immurok "$service"; then
        case "$action" in
            add) echo "OK:ALREADY_PRESENT($service)" ;;
            remove) echo "ERROR:MANAGED_BY_NIXOS($service)" ;;
        esac
    else
        case "$action" in
            add) echo "ERROR:MANAGED_BY_NIXOS($service)" ;;
            remove) echo "OK:NOT_PRESENT($service)" ;;
        esac
    fi
done
