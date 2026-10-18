// Menus shown before a match: the main menu, settings, and the build picker.
// The game waits until a build is chosen.
enum MENU { MAIN, SETTINGS, BUILD, PAUSE, PLAYMODE, LOBBY, JOIN, ABOUT }
net_ensure();   // keeps Steam running and listening for friends' invites
// Opened mid-match with Esc: the pause menu goes over the game, which keeps running
// underneath (like an online game). Only your own input is blocked while it's up.
paused = variable_global_exists("menu_pausing") && global.menu_pausing;
global.menu_pausing = false;
if (paused) global.pause_open = true; else global.menu_open = true;
if (!paused) global.build = -1;
screen = paused ? MENU.PAUSE : MENU.MAIN;
// Straight back to the host lobby after a match ends.
if (!paused && global.return_to_lobby) {
	screen = MENU.LOBBY;
	global.return_to_lobby = false;
	global.net_in_match = false;   // tell anyone on LAN the host is back in the lobby
	net_lobby_changed();
}
// Lost the host in the middle of its match: the game list, showing why.
join_online = global.net_mode == "steam";   // the join screen lists Steam lobbies, not LAN games
if (!paused && global.net_after_drop) {
	global.net_after_drop = false;
	screen = MENU.JOIN;
	if (join_online) net_steam_join_open(true); else net_join_open(true);
}
// Back at the main menu: stop hosting.
if (!paused && screen == MENU.MAIN) net_host_close();
lobby_joined = global.net_role == "client";   // this lobby is someone else's (we joined over LAN or online)
t = 0;
hover_screen = -1;   // the hover tick: last frame's screen and highlighted button
hover_sel = -1;
input_lock = paused ? 6 : 0;   // frames to ignore input after switching screens

// ---------- Settings ----------
set_sel = 0;              // 0 resolution, 1 fullscreen, 2 ui scale, 3 hud, 4 music, 5 sfx, 6 back
set_rows = 7;
set_w = 600;
set_x = function() { return display_get_gui_width() / 2 - set_w / 2; };
set_y = function(_i) { return display_get_gui_height() / 2 - 215 + _i * (btn_h + 12); };

// ---------- Pause menu ----------
pause_sel = 0;
// No replaying in a LAN match: the host's island is everyone's.
var _lan_match = global.net_role == "client" || (global.net_role == "host" && array_length(global.net_match_socks) > 0);
pause_items = _lan_match ? ["RESUME", "MAIN MENU", "QUIT"] : ["RESUME", "REPLAY MAP", "MAIN MENU", "QUIT"];
resume = function() {
	// Clear Esc, or the world sees the same press this frame and pauses again straight away.
	keyboard_clear(vk_escape);
	var _me = iso_local_player();
	if (instance_exists(_me)) _me.input.pause = false;   // this same Esc mustn't reopen the menu
	global.pause_open = false;
	instance_destroy();
};

// ---------- Main menu ----------
game_title = "GOONIES";
main_sel = 0;
main_items = [
	{ label: "PLAY",     enabled: true },
	{ label: "ABOUT",    enabled: true },
	{ label: "SETTINGS", enabled: true },
	{ label: "QUIT",     enabled: true },
];
btn_w = 360;
btn_h = 64;
btn_gap = 20;
btn_x = function() { return display_get_gui_width() / 2 - btn_w / 2; };
btn_y = function(_i) { return display_get_gui_height() / 2 - 60 + _i * (btn_h + btn_gap); };

// ---------- Play: host or join ----------
mode_sel = 0;
mode_items = [
	{ label: "HOST",        enabled: true },
	{ label: "JOIN ONLINE", enabled: net_steam_ok(), note: "NO STEAM" },
	{ label: "JOIN LAN",    enabled: true },
	{ label: "BACK",     enabled: true },
];

// ---------- Host lobby: up to 12 players (dummies for now, see global.lobby_slots) ----------
lobby_sel = 2;            // 0 add, 1 remove, 2 play, 3 back
lobby_items = ["ADD DUMMY", "REMOVE DUMMY", "PLAY", "BACK"];
lobby_btn_w = 270;
lobby_btn_gap = 24;
lobby_btn_x = function(_i) {
	var _total = 4 * lobby_btn_w + 3 * lobby_btn_gap;
	return (display_get_gui_width() - _total) / 2 + _i * (lobby_btn_w + lobby_btn_gap);
};
lobby_btn_y = function() { return display_get_gui_height() / 2 + 146; };
// A second row: OPEN TO LAN, OPEN ONLINE and INVITE FRIENDS, together as wide as the first.
lan_btn_w = (4 * lobby_btn_w + lobby_btn_gap) / 3;
lan_btn_y = function() { return lobby_btn_y() + btn_h + 18; };
lan_btn_x = function(_k) { return lobby_btn_x(0) + _k * (lan_btn_w + lobby_btn_gap); };
lobby_net_labels = function() {
	return [net_lan_open() ? "CLOSE LAN" : "OPEN TO LAN", net_online_open() ? "CLOSE ONLINE" : "OPEN ONLINE", "INVITE FRIENDS"];
};
// Buttons: 0 add, 1 remove, 2 play, 3 back, 4 open/close LAN, 5 open/close online,
// 6 invite friends (the Steam overlay). One way of hosting at a time. Joiners only get BACK.
lobby_enabled = function(_i) {
	if (lobby_joined) return _i == 3;
	var _n = array_length(global.lobby_slots);
	if (_i == 0) return _n < LOBBY_MAX;
	if (_i == 1) return lobby_last_dummy() >= 1;
	if (_i == 4) return !net_online_open();
	if (_i == 5) return net_steam_ok() && !net_lan_open();
	if (_i == 6) return net_online_open() && oNet.steam_lobby != 0;
	return true;
};
// Put the highlight back on a button that can be pressed.
lobby_fix_sel = function() {
	lobby_sel = lobby_enabled(2) ? 2 : (lobby_enabled(0) ? 0 : 3);
};
// BACK: a host stops hosting; a joiner leaves and goes back to the game list.
leave_lobby = function() {
	if (lobby_joined) {
		lobby_joined = false;
		net_drop("");
		open_join(false);
	} else {
		net_host_close();
		go_to(MENU.PLAYMODE);
	}
};

// ---------- Join: games found on the network, or online through Steam ----------
join_sel = 0;
// The join screen for the way we last played (online or LAN). _keep_status keeps the
// reason we left a game on screen.
open_join = function(_keep_status) {
	join_online = global.net_mode == "steam";
	if (join_online) net_steam_join_open(_keep_status); else net_join_open(_keep_status);
	join_sel = 0;
	go_to(MENU.JOIN);
};
join_w = 640;
join_x = function() { return display_get_gui_width() / 2 - join_w / 2; };
join_y = function(_i) { return display_get_gui_height() / 2 - 180 + _i * (btn_h + 12); };
// LAN: the games heard so far, then THIS PC (only when a second copy of the game on this
// computer is hosting), then BACK. Online: the lobbies Steam listed, then REFRESH and BACK.
// act is what pressing it does: "lan" (joins ip), "steam" (joins lobby), "refresh" or "back".
join_items = function() {
	var _a = [];
	if (join_online) {
		if (instance_exists(oNet)) {
			var _g = oNet.steam_games;
			for (var _i = 0; _i < min(4, array_length(_g)); _i++) {
				var _label = _g[_i].host + "   " + string(_g[_i].players) + "/" + string(LOBBY_MAX) + (_g[_i].in_match ? "  IN MATCH" : "");
				array_push(_a, { label: _label, act: "steam", lobby: _g[_i].lobby });
			}
		}
		array_push(_a, { label: "REFRESH", act: "refresh" });
	} else {
		if (instance_exists(oNet)) {
			var _g = oNet.games;
			for (var _i = 0; _i < min(4, array_length(_g)); _i++) {
				var _label = _g[_i].ip + "   " + string(_g[_i].players) + "/" + string(_g[_i].max) + (_g[_i].in_match ? "  IN MATCH" : "");
				array_push(_a, { label: _label, act: "lan", ip: _g[_i].ip });
			}
		}
		// THIS PC: only when another copy of the game on this computer is hosting.
		if (instance_exists(oNet) && oNet.local_host) array_push(_a, { label: "THIS PC", act: "lan", ip: "127.0.0.1" });
	}
	array_push(_a, { label: "BACK", act: "back" });
	return _a;
};
// Inside each slot: the build picker (click its left or right half).
slot_build_x = 290;
slot_build_w = 150;

// Lobby PLAY: everyone's in. Your build and colour come from slot 1. Every other slot goes
// on a random open tile: dummies as dummies, LAN players as players steered from their
// own game (each is sent "start" to build the same island). Then the 2-1-GO countdown starts.
start_match = function() {
	if (array_length(global.lobby_slots) == 0) lobby_add();
	global.build = global.lobby_builds[0];
	with (oIsoPlayer) if (is_local) {
		body_set_colour(global.lobby_slots[0]);
		build = global.build;
	}
	global.net_in_match = true;
	global.net_match_socks = [];
	global.net_out_events = [];
	for (var _i = 1; _i < array_length(global.lobby_slots); _i++) {
		var _vars = { colour_idx: global.lobby_slots[_i], player_id: _i, build: global.lobby_builds[_i] };   // slot 2 is P1, and so on
		if (global.lobby_kind[_i] == "player") {
			_vars.net_local = false;
			_vars.net_sock = global.lobby_sock[_i];
			iso_spawn_body(oIsoPlayer, _vars);
			array_push(global.net_match_socks, _vars.net_sock);
			net_send(_vars.net_sock, { t: "start", seed: global.iso_seed, you: _i, build: global.lobby_builds[_i] });
		} else {
			iso_spawn_body(oIsoDummy, _vars);
		}
	}
	net_lobby_changed();   // anyone who joined after PLAY sees the host is in a match
	match_start();
	global.menu_open = false;
	instance_destroy();
};
// Twelve slots in two columns of six.
slot_w = 460;
slot_h = 48;
slot_x = function(_i) { return display_get_gui_width() / 2 - slot_w - 12 + (_i div 6) * (slot_w + 24); };
slot_y = function(_i) { return display_get_gui_height() / 2 - 230 + (_i mod 6) * (slot_h + 14); };

// ---------- Builds: names and colours for the lobby (see Build pick in scr_iso) ----------
cards = global.build_cards;
card_w = 300;
card_h = 380;
card_gap = 40;

// Screen rectangle of card _i on the GUI layer.
card_x = function(_i) {
	var _total = 3 * card_w + 2 * card_gap;
	return (display_get_gui_width() - _total) / 2 + _i * (card_w + card_gap);
};
card_y = function() { return display_get_gui_height() / 2 - card_h / 2 + 30; };

// ---------- About: credits and the trailer ----------
about_sel = 0;              // 0 play trailer, 1 back
about_items = ["PLAY TRAILER", "BACK"];
trailer_open = false;       // the trailer window is up
trailer_seen = false;       // it got past loading
trailer_w = 640;
trailer_h = 360;
// The window is 16:9 and 80% of the screen's width, made smaller if that's too tall
// to leave room for its title bar and the hint under it.
trailer_fit = function() {
	trailer_w = floor(min(display_get_gui_width() * 0.8, (display_get_gui_height() - 200) * 16 / 9));
	trailer_h = floor(trailer_w * 9 / 16);
};
trailer_x = function() { return display_get_gui_width() / 2 - trailer_w / 2; };
trailer_y = function() { return display_get_gui_height() / 2 - trailer_h / 2 + 20; };
// The X button in the window's title bar.
trailer_xbtn = function() { return [trailer_x() + trailer_w - 34, trailer_y() - 36]; };
// The trailer's own volume slider, in the title bar left of the X: [x, centre y, width].
trailer_vol = 1;            // 0 to 1, kept until the game closes
trailer_drag = false;       // the knob is being dragged
trailer_slider = function() { return [trailer_x() + trailer_w - 34 - 30 - 200, trailer_y() - 22, 200]; };
trailer_play = function() {
	trailer_close();
	video_open("trailer.mp4");   // an Included File (datafiles/trailer.mp4)
	video_enable_loop(false);
	video_set_volume(trailer_vol);
	trailer_open = true;
	trailer_seen = false;
	trailer_fit();
};
trailer_close = function() {
	if (!trailer_open) return;
	video_close();
	trailer_open = false;
};

go_to = function(_screen) {
	screen = _screen;
	input_lock = 6;
};

// A chunky pixel button. _state: 0 normal, 1 highlighted, 2 greyed out.
draw_pixel_button = function(_x, _y, _w, _h, _label, _state, _arrows = true) {
	var _border = [make_colour_rgb(70, 76, 100), c_white, make_colour_rgb(50, 54, 70)][_state];
	var _fill = [make_colour_rgb(26, 30, 52), make_colour_rgb(44, 52, 92), make_colour_rgb(30, 32, 42)][_state];
	var _text = [make_colour_rgb(210, 216, 235), c_white, make_colour_rgb(90, 94, 110)][_state];
	draw_set_colour(c_black);
	draw_rectangle(_x - 4, _y - 4, _x + _w + 4, _y + _h + 4, false);
	draw_set_colour(_border);
	draw_rectangle(_x, _y, _x + _w, _y + _h, false);
	draw_set_colour(_fill);
	draw_rectangle(_x + 6, _y + 6, _x + _w - 6, _y + _h - 6, false);
	draw_set_colour(merge_colour(_fill, c_white, 0.08));
	draw_rectangle(_x + 6, _y + 6, _x + _w - 6, _y + 10, false);
	pixel_text(_x + _w / 2, _y + _h / 2 - 12, _label, 3, _text, fa_center);
	if (_state == 1 && _arrows) {
		// Little arrows either side of the picked button.
		pixel_text(_x - 40, _y + _h / 2 - 12, ">", 3, c_white, fa_center);
		pixel_text(_x + _w + 40, _y + _h / 2 - 12, "<", 3, c_white, fa_center);
	}
};
