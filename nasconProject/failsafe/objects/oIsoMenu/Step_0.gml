t++;
// Hover tick when the highlighted button changes on the same screen. A new screen resets it silently.
var _hsel = [main_sel, set_sel, 0, pause_sel, mode_sel, lobby_sel, join_sel, about_sel][screen];
if (screen == hover_screen && _hsel != hover_sel) audio_ui_hover();
hover_screen = screen;
hover_sel = _hsel;
// A friend's Steam invite (or Join Game on the friends list): leave this and join them.
if (screen != MENU.PAUSE && global.net_invite != 0) {
	trailer_close();
	var _lobby = global.net_invite;
	global.net_invite = 0;
	lobby_joined = false;
	net_steam_join(_lobby);   // stops hosting, or leaves another game, first
	open_join(true);          // keeps "JOINING..." up
	exit;
}
if (trailer_open && screen != MENU.ABOUT) trailer_close();
if (input_lock > 0) { input_lock--; exit; }

var _mx = device_mouse_x_to_gui(0);
var _my = device_mouse_y_to_gui(0);
var _confirm = keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space);
var _back = keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace);
var _up = keyboard_check_pressed(ord("W")) || keyboard_check_pressed(vk_up);
var _down = keyboard_check_pressed(ord("S")) || keyboard_check_pressed(vk_down);

switch (screen) {
	case MENU.MAIN: {
		var _n = array_length(main_items);
		// Up/down skip greyed-out items.
		if (_up)   do { main_sel = (main_sel + _n - 1) mod _n; } until (main_items[main_sel].enabled);
		if (_down) do { main_sel = (main_sel + 1) mod _n; } until (main_items[main_sel].enabled);
		var _over = -1;
		for (var _i = 0; _i < _n; _i++) {
			if (point_in_rectangle(_mx, _my, btn_x(), btn_y(_i), btn_x() + btn_w, btn_y(_i) + btn_h)) _over = _i;
		}
		if (_over != -1 && main_items[_over].enabled) main_sel = _over;
		if (_confirm || (mouse_check_button_pressed(mb_left) && _over == main_sel)) {
			audio_ui_click();   // pressed buttons click; Esc and back keys don't
			switch (main_items[main_sel].label) {
				case "PLAY":     go_to(MENU.PLAYMODE); break;
				case "ABOUT":    about_sel = 0; go_to(MENU.ABOUT); break;
				case "SETTINGS": go_to(MENU.SETTINGS); break;
				case "QUIT":     game_end(); break;
			}
		}
		break;
	}

	case MENU.ABOUT: {
		if (trailer_open) {
			trailer_fit();   // follows a window or UI scale change
			// Esc, the X button, or the end of the video closes the window.
			var _st = video_get_status();
			if (_st == video_status_playing) trailer_seen = true;
			// Volume: drag or click the slider, or A / D in 10% steps.
			var _sl = trailer_slider();
			var _on_sl = point_in_rectangle(_mx, _my, _sl[0] - 8, _sl[1] - 14, _sl[0] + _sl[2] + 8, _sl[1] + 14);
			if (mouse_check_button_pressed(mb_left) && _on_sl) trailer_drag = true;
			if (!mouse_check_button(mb_left)) trailer_drag = false;
			var _kd = (keyboard_check_pressed(ord("D")) || keyboard_check_pressed(vk_right)) - (keyboard_check_pressed(ord("A")) || keyboard_check_pressed(vk_left));
			if (trailer_drag) trailer_vol = clamp((_mx - _sl[0]) / _sl[2], 0, 1);
			else if (_kd != 0) trailer_vol = clamp(round(trailer_vol * 10 + _kd) / 10, 0, 1);
			video_set_volume(trailer_vol);
			var _xb = trailer_xbtn();
			var _on_x = point_in_rectangle(_mx, _my, _xb[0], _xb[1], _xb[0] + 30, _xb[1] + 30);
			var _ended = trailer_seen && (_st == video_status_closed || video_get_position() >= video_get_duration() - 50);
			if (_on_x && mouse_check_button_pressed(mb_left)) audio_ui_click();
			if (_back || (_on_x && mouse_check_button_pressed(mb_left)) || _ended) {
				trailer_close();
				input_lock = 6;
			}
			break;
		}
		if (_back) { go_to(MENU.MAIN); break; }
		if (_up || _down) about_sel = 1 - about_sel;
		var _over = -1;
		for (var _i = 0; _i < 2; _i++) {
			if (point_in_rectangle(_mx, _my, btn_x(), btn_y(_i + 1), btn_x() + btn_w, btn_y(_i + 1) + btn_h)) _over = _i;
		}
		if (_over != -1) about_sel = _over;
		if (_confirm || (mouse_check_button_pressed(mb_left) && _over == about_sel)) {
			audio_ui_click();
			if (about_sel == 0) { trailer_play(); input_lock = 6; }
			else go_to(MENU.MAIN);
		}
		break;
	}

	case MENU.SETTINGS: {
		if (_back) { go_to(MENU.MAIN); break; }
		// Resolution is locked while fullscreen is on, so it's skipped.
		var _locked = global.set_fullscreen;
		if (_up)   do { set_sel = (set_sel + set_rows - 1) mod set_rows; } until (!(_locked && set_sel == 0));
		if (_down) do { set_sel = (set_sel + 1) mod set_rows; } until (!(_locked && set_sel == 0));
		var _over = -1;
		for (var _i = 0; _i < set_rows; _i++) {
			if (_locked && _i == 0) continue;
			if (point_in_rectangle(_mx, _my, set_x(), set_y(_i), set_x() + set_w, set_y(_i) + btn_h)) _over = _i;
		}
		if (_over != -1) set_sel = _over;
		if (_locked && set_sel == 0) set_sel = 1;
		var _press = _confirm || (mouse_check_button_pressed(mb_left) && _over == set_sel);
		if (set_sel == set_rows - 1) {
			if (_press) { audio_ui_click(); go_to(MENU.MAIN); }
			break;
		}
		// A / D steps the option down or up, Enter steps it up, and clicking
		// the left or right half of the row (where the < > arrows are) steps that way.
		var _dir = (keyboard_check_pressed(ord("D")) || keyboard_check_pressed(vk_right)) - (keyboard_check_pressed(ord("A")) || keyboard_check_pressed(vk_left));
		if (_confirm) _dir = 1;
		if (mouse_check_button_pressed(mb_left) && _over == set_sel) _dir = (_mx < set_x() + set_w / 2) ? -1 : 1;
		if (_dir != 0) {
			audio_ui_click();
			if (set_sel == 3) {
				global.set_hud = !global.set_hud;
			} else if (set_sel == 4) {
				global.set_music = clamp(global.set_music + _dir, 0, 10);
			} else if (set_sel == 5) {
				global.set_sfx = clamp(global.set_sfx + _dir, 0, 10);
			} else if (set_sel == 2) {
				// UI scale only changes the GUI, not the window.
				var _n = array_length(global.ui_scales);
				global.set_ui = clamp(global.set_ui + _dir, 0, _n - 1);
				settings_apply_view();
			} else {
				var _n = array_length(global.resolutions);
				if (set_sel == 0) global.set_res = clamp(global.set_res + _dir, 0, _n - 1);
				else global.set_fullscreen = !global.set_fullscreen;
				settings_apply();
			}
			settings_save();
			input_lock = 6;
		}
		break;
	}

	case MENU.PAUSE: {
		if (_back) { resume(); break; }
		var _n = array_length(pause_items);
		if (_up)   pause_sel = (pause_sel + _n - 1) mod _n;
		if (_down) pause_sel = (pause_sel + 1) mod _n;
		var _over = -1;
		for (var _i = 0; _i < _n; _i++) {
			if (point_in_rectangle(_mx, _my, btn_x(), btn_y(_i), btn_x() + btn_w, btn_y(_i) + btn_h)) _over = _i;
		}
		if (_over != -1) pause_sel = _over;
		if (_confirm || (mouse_check_button_pressed(mb_left) && _over == pause_sel)) {
			audio_ui_click();   // pressed buttons click; Esc and back keys don't
			switch (pause_items[pause_sel]) {
				case "RESUME": resume(); break;
				case "REPLAY MAP": global.iso_next_seed = global.iso_seed; room_restart(); break;   // same island again
				case "MAIN MENU":   // a fresh island and the main menu (joined over LAN, this leaves the host)
					if (global.net_role == "client") net_drop(""); else room_restart();
					break;
				case "QUIT": game_end(); break;
			}
		}
		break;
	}

	case MENU.PLAYMODE: {
		if (_back) { go_to(MENU.MAIN); break; }
		var _n = array_length(mode_items);
		if (_up)   do { mode_sel = (mode_sel + _n - 1) mod _n; } until (mode_items[mode_sel].enabled);
		if (_down) do { mode_sel = (mode_sel + 1) mod _n; } until (mode_items[mode_sel].enabled);
		var _over = -1;
		for (var _i = 0; _i < _n; _i++) {
			if (point_in_rectangle(_mx, _my, btn_x(), btn_y(_i), btn_x() + btn_w, btn_y(_i) + btn_h)) _over = _i;
		}
		if (_over != -1 && mode_items[_over].enabled) mode_sel = _over;
		if (_confirm || (mouse_check_button_pressed(mb_left) && _over == mode_sel)) {
			audio_ui_click();   // pressed buttons click; Esc and back keys don't
			switch (mode_items[mode_sel].label) {
				case "HOST":
					if (array_length(global.lobby_slots) == 0) lobby_add();   // slot 1 is you
					lobby_joined = false;
					lobby_sel = 2;
					go_to(MENU.LOBBY);
					break;
				case "JOIN ONLINE":
					net_steam_join_open();
					join_online = true;
					join_sel = 0;
					go_to(MENU.JOIN);
					break;
				case "JOIN LAN":
					net_join_open();
					join_online = false;
					join_sel = 0;
					go_to(MENU.JOIN);
					break;
				case "BACK": go_to(MENU.MAIN); break;
			}
		}
		break;
	}

	case MENU.LOBBY: {
		// Joined someone and lost the connection: back to the game list, showing why.
		if (lobby_joined && global.net_role != "client") {
			lobby_joined = false;
			open_join(true);
			break;
		}
		if (_back) { leave_lobby(); break; }
		if (!lobby_joined && array_length(global.lobby_slots) == 0) lobby_add();
		// A / D (or W / S) move along the buttons, skipping greyed-out ones.
		var _prev = keyboard_check_pressed(ord("A")) || _up;
		var _next = keyboard_check_pressed(ord("D")) || _down;
		if (!lobby_enabled(lobby_sel)) lobby_fix_sel();
		if (_prev) do { lobby_sel = (lobby_sel + 6) mod 7; } until (lobby_enabled(lobby_sel));
		if (_next) do { lobby_sel = (lobby_sel + 1) mod 7; } until (lobby_enabled(lobby_sel));
		var _over = -1;
		for (var _i = 0; _i < 4; _i++) {
			if (point_in_rectangle(_mx, _my, lobby_btn_x(_i), lobby_btn_y(), lobby_btn_x(_i) + lobby_btn_w, lobby_btn_y() + btn_h)) _over = _i;
		}
		for (var _k = 0; _k < 3; _k++) {
			if (point_in_rectangle(_mx, _my, lan_btn_x(_k), lan_btn_y(), lan_btn_x(_k) + lan_btn_w, lan_btn_y() + btn_h)) _over = 4 + _k;
		}
		if (_over != -1 && lobby_enabled(_over)) lobby_sel = _over;
		if (_confirm || (mouse_check_button_pressed(mb_left) && _over == lobby_sel)) {
			audio_ui_click();   // pressed buttons click; Esc and back keys don't
			switch (lobby_sel) {
				case 0: lobby_add(); break;
				case 1: lobby_remove(); break;
				case 2: start_match(); break;
				case 3: leave_lobby(); break;
				case 4: if (net_lan_open()) net_host_close(); else net_host_open(); break;
				case 5: if (net_online_open()) net_host_close(); else net_steam_host_open(); break;
				case 6: steam_lobby_activate_invite_overlay(); break;
			}
			if (instance_exists(id) && !lobby_enabled(lobby_sel)) lobby_fix_sel();
		}
		break;
	}

	case MENU.JOIN: {
		if (_back) { net_drop(""); net_join_close(); go_to(MENU.PLAYMODE); break; }
		// Connected and the host gave us a slot: into their lobby.
		if (global.net_role == "client" && global.net_my_slot >= 0) {
			net_join_close();
			lobby_joined = true;
			lobby_sel = 3;
			go_to(MENU.LOBBY);
			break;
		}
		var _items = join_items();
		var _n = array_length(_items);
		join_sel = clamp(join_sel, 0, _n - 1);
		if (_up)   join_sel = (join_sel + _n - 1) mod _n;
		if (_down) join_sel = (join_sel + 1) mod _n;
		var _over = -1;
		for (var _i = 0; _i < _n; _i++) {
			if (point_in_rectangle(_mx, _my, join_x(), join_y(_i), join_x() + join_w, join_y(_i) + btn_h)) _over = _i;
		}
		if (_over != -1) join_sel = _over;
		if (_confirm || (mouse_check_button_pressed(mb_left) && _over == join_sel)) {
			audio_ui_click();   // pressed buttons click; Esc and back keys don't
			var _it = _items[join_sel];
			switch (_it.act) {
				case "back":
					net_drop("");
					net_join_close();
					go_to(MENU.PLAYMODE);
					break;
				case "refresh": if (global.net_role != "client") net_steam_join_open(); break;
				case "lan":     if (global.net_role != "client") net_join_connect(_it.ip); break;
				case "steam":   if (global.net_role != "client") net_steam_join(_it.lobby); break;
			}
		}
		break;
	}
}
