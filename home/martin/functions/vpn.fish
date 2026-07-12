function vpn
    if openvpn3 sessions-list 2>/dev/null | grep -q hcommons
        echo "VPN already running"
        return 0
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
