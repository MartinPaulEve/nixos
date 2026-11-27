# immurok's Linux companion app, built from source: the daemon that talks to
# the fingerprint key over Bluetooth LE, the PAM module, the CLI/TUI
# (immurok-cli, imk), the session agent and the GTK settings app.
#
# Upstream (https://immurok.com/download/) ships deb/rpm/Arch packages and a
# `make install` that writes into /usr/local, /etc/pam.d and /etc/systemd.
# This is that install laid out as a Nix package instead; the parts that are
# system configuration rather than files (the daemon's account, the units
# being enabled, the PAM lines) are in ./default.nix.
#
# To bump: set `version`, set both hashes to lib.fakeHash, rebuild, and copy
# back the hash each failure reports (the source's first, then cargo's).
{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, glib
, gobject-introspection
, wrapGAppsHook4
, dbus
, gtk4
, libadwaita
, libnotify
, linux-pam
, python3
}:

let
  # Two of the pieces are Python scripts: the helper the daemon runs for all
  # its Bluetooth traffic (dbus-fast), and the "touch the key" dialog
  # (PyGObject, GTK 4, libadwaita).
  python = python3.withPackages (ps: [ ps.dbus-fast ps.pygobject3 ]);
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "immurok";
  version = "0.9.4";

  src = fetchFromGitHub {
    owner = "immurok";
    repo = "app-linux-rs";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DyPXYTilZvw3XYPZTerdHP2q3uWNXGm2MAXv5BkotNg=";
  };

  cargoHash = "sha256-iohheKYsPlw+LuZVz+900Adbr22RM4/Yqtn6K2d3oSA=";

  nativeBuildInputs = [
    pkg-config
    glib # glib-compile-resources, for the settings app's icons
    gobject-introspection
    wrapGAppsHook4
  ];

  buildInputs = [
    dbus # the daemon's BlueZ client
    gtk4
    libadwaita
    linux-pam
    python
  ];

  # The daemon and the session agent find these two on PATH, which under
  # systemd is not the user's. Point them at the store instead.
  postPatch = ''
    substituteInPlace crates/immurok-daemon/src/ble.rs \
      --replace-fail 'Command::new("python3")' 'Command::new("${python}/bin/python3")'
    substituteInPlace crates/immurok-session-agent/src/main.rs \
      --replace-fail 'Command::new("notify-send")' 'Command::new("${libnotify}/bin/notify-send")'
  '';

  # The PAM module is plain C beside the Rust workspace, with its own tests.
  postBuild = ''
    make -C pam
  '';

  postCheck = ''
    make -C pam test
  '';

  # Upstream's own tests run as part of the build, bar one: it asserts that
  # process 1 belongs to somebody else, and inside the build sandbox process
  # 1 is the build itself.
  checkFlags = [ "--skip=tty::tests::pid_1_is_not_mine" ];

  # Everything upstream's package carries (packaging/stage.sh), with /usr
  # read as $out. The helper scripts go beside the binaries because that is
  # where the binaries look for them.
  postInstall = ''
    install -Dm755 pam/pam_immurok.so -t $out/lib/security
    install -Dm755 scripts/immurok-auth-dialog scripts/ble-notify-helper.py -t $out/bin
    install -Dm755 ${./pam-helper.sh} $out/bin/immurok-pam-helper

    install -Dm644 packaging/immurok-daemon.service -t $out/lib/systemd/system
    install -Dm644 packaging/immurok-session-agent.service -t $out/lib/systemd/user
    install -Dm644 packaging/dbus/immurok.conf -t $out/share/dbus-1/system.d
    install -Dm644 packaging/com.immurok.Settings.service -t $out/share/dbus-1/services
    install -Dm644 packaging/polkit/49-immurok.rules -t $out/share/polkit-1/rules.d
    install -Dm644 packaging/com.immurok.Settings.desktop -t $out/share/applications
    install -Dm644 packaging/com.immurok.Settings.autostart.desktop \
      $out/etc/xdg/autostart/com.immurok.Settings.desktop
    mkdir -p $out/share/icons
    cp -r packaging/icons/hicolor $out/share/icons/

    mkdir -p $out/share/polkit-1/actions
    substitute scripts/com.immurok.pam-helper.policy.in \
      $out/share/polkit-1/actions/com.immurok.pam-helper.policy \
      --replace-fail @HELPER_PATH@ $out/bin/immurok-pam-helper

    substituteInPlace \
      $out/lib/systemd/system/immurok-daemon.service \
      $out/lib/systemd/user/immurok-session-agent.service \
      $out/share/dbus-1/services/com.immurok.Settings.service \
      --replace-fail /usr/bin/ $out/bin/
  '';

  # Only the two GTK programs want the GTK environment; wrapping the daemon
  # and the rest in it as well would be noise.
  dontWrapGApps = true;

  postFixup = ''
    wrapProgram $out/bin/immurok-gui "''${gappsWrapperArgs[@]}"
    wrapProgram $out/bin/immurok-auth-dialog "''${gappsWrapperArgs[@]}"
  '';

  meta = {
    description = "Linux companion app for the immurok wireless fingerprint key";
    homepage = "https://immurok.com";
    changelog = "https://github.com/immurok/app-linux-rs/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "immurok-cli";
  };
})
