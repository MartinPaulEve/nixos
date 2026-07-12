function vpnoff
	openvpn3 session-manage --config hcommons --disconnect
end
