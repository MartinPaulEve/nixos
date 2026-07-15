function vpn
    if openvpn3 sessions-list 2>/dev/null | grep -q hcommons
        echo "VPN already running"
        return 0
    end

    set -l server_ip (getent ahosts openvpn.hcommons.org | awk '/STREAM/ {print $1; exit}')
    if test -z "$server_ip"
        echo "Cannot resolve openvpn.hcommons.org" >&2
        return 1
    end
    set -l rt (ip -4 route get $server_ip 2>/dev/null | head -1)
    set -l gw (echo $rt | awk '{for (i=1;i<=NF;i++) if ($i=="via") print $(i+1)}')
    set -l dev (echo $rt | awk '{for (i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')
    if test -z "$gw" -o -z "$dev"
        echo "Cannot determine pre-VPN route to $server_ip" >&2
        return 1
    end
    echo "Pinning $server_ip via $gw dev $dev (sudo)"
    if not sudo ip route replace $server_ip/32 via $gw dev $dev
        echo "Failed to add host-route to VPN server" >&2
        return 1
    end

    set -l user (op read 'op://BotAccess/Hcommons OpenVPN/username')
    set -l pass (op read 'op://BotAccess/Hcommons OpenVPN/password')
    set -l otp (op item get 'Hcommons OpenVPN' --vault='BotAccess' --otp)

    set -l expfile (mktemp /tmp/vpn-expect.XXXXXX)
    printf '%s\n' \
        'log_user 1' \
        'set timeout 30' \
        'spawn openvpn3 session-start --config hcommons --background' \
        'expect "Auth User name:"' \
        'send "$env(VPN_USER)\r"' \
        'expect "Auth Password:"' \
        'send "$env(VPN_PASS)\r"' \
        'expect "Enter Authenticator Code:"' \
        'send "$env(VPN_OTP)\r"' \
        'expect {' \
        '    "running in the background" { exit 0 }' \
        '    timeout { exit 1 }' \
        '    eof { exit 1 }' \
        '}' >$expfile

    begin
        set -lx VPN_USER $user
        set -lx VPN_PASS $pass
        set -lx VPN_OTP $otp
        expect -f $expfile
    end
    set -l ret $status
    rm -f $expfile
    return $ret
end
