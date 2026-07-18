# Registers the Zotero LibreOffice integration extension into LibreOffice, for
# this user only.
#
# This used to be a system.userActivationScripts fragment in packages.nix, but
# switch-to-configuration runs user activation for *every* live user session,
# including gdm's greeter (gdm-greeter). The greeter's transient user D-Bus is
# not reachable the way a real login's is, so activation blocked on a ~25s D-Bus
# timeout per greeter and printed "user activation for gdm-greeter failed".
# Running it as a Home Manager activation keeps it to this account (never gdm)
# and registers into the real LibreOffice profile. `timeout` bounds any stall so
# a misbehaving unopkg can never hang the switch.
{ lib, pkgs, ... }:

{
  home.activation.zoteroLibreOfficeIntegration =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      libreoffice_program="${pkgs.libreoffice}/lib/libreoffice/program"
      zotero_oxt="${pkgs.zotero}/lib/integration/libreoffice/Zotero_LibreOffice_Integration.oxt"

      if [ -x "$libreoffice_program/unopkg" ] && [ -f "$zotero_oxt" ]; then
        (
          cd "$libreoffice_program"
          $DRY_RUN_CMD timeout 60 ./unopkg add --force "$zotero_oxt"
        ) || echo "Zotero LibreOffice integration registration failed" >&2
      else
        echo "Could not locate LibreOffice unopkg or Zotero LibreOffice extension" >&2
      fi
    '';
}
