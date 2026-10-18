tick++;
if (role == "host") {
	// Once a second: tell the network (or Steam's game list) we're here, and resend the
	// lobby (doubles as a keep-alive).
	if (tick mod 60 == 0) {
		net_broadcast_presence();
		net_send_lobby();
		if (global.net_mode == "steam") net_steam_check_members();
	}
} else if (role == "client") {
	// Online, keep saying hello until the host's lobby arrives (the first one can be missed).
	if (global.net_mode == "steam" && !connecting && global.net_my_slot < 0 && tick mod 60 == 0) net_send(sock, { t: "hello" });
	var _limit = (global.net_mode == "steam") ? NET_STEAM_TIMEOUT : 6000;
	if (current_time - last_heard > _limit) net_drop(connecting ? "COULDN'T CONNECT" : "LOST CONNECTION TO THE HOST");
}

// The LAN game list: once a second, check whether a copy on this PC is hosting (for THIS PC).
if (udp_listen >= 0 && tick mod 60 == 0) net_check_local_host();

// Forget LAN games we haven't heard from for a while.
for (var _i = array_length(games) - 1; _i >= 0; _i--) {
	if (current_time - games[_i].seen > 4000) array_delete(games, _i, 1);
}
// The online game list: ask Steam again every few seconds while it's up.
if (browsing && role == "none" && current_time - list_at > (listing ? 15000 : 5000)) net_steam_list();
