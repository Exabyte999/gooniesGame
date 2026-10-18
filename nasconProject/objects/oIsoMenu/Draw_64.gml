var _gw = display_get_gui_width();
var _gh = display_get_gui_height();

// Dim the island behind the menus. The pause menu is lighter, since the game keeps running.
draw_set_alpha((screen == MENU.PAUSE) ? 0.3 : 0.6);
draw_set_colour(make_colour_rgb(12, 18, 40));
draw_rectangle(0, 0, _gw, _gh, false);
draw_set_alpha(1);

switch (screen) {
	case MENU.MAIN: {
		var _bob = round(sin(t / 20) * 4);
		pixel_text(_gw / 2, _gh / 2 - 250 + _bob, game_title, 10, c_white, fa_center);
		// A chain of pixel links under the title.
		for (var _i = 0; _i < 15; _i++) {
			var _lx = _gw / 2 - 210 + _i * 30;
			draw_set_colour(c_black);
			draw_rectangle(_lx - 2, _gh / 2 - 152, _lx + 22, _gh / 2 - 138, false);
			draw_set_colour((_i mod 2 == 0) ? make_colour_rgb(160, 160, 176) : make_colour_rgb(112, 112, 128));
			draw_rectangle(_lx, _gh / 2 - 150, _lx + 20, _gh / 2 - 140, false);
		}
		for (var _i = 0; _i < array_length(main_items); _i++) {
			var _it = main_items[_i];
			var _state = !_it.enabled ? 2 : (_i == main_sel ? 1 : 0);
			draw_pixel_button(btn_x(), btn_y(_i), btn_w, btn_h, _it.label, _state);
			if (!_it.enabled) pixel_text(btn_x() + btn_w - 16, btn_y(_i) + btn_h / 2 - 8, variable_struct_exists(_it, "note") ? _it.note : "SOON", 2, make_colour_rgb(90, 94, 110), fa_right);
		}
		pixel_text(_gw / 2, _gh - 60, "W / S OR MOUSE TO CHOOSE     ENTER OR CLICK TO SELECT", 2, make_colour_rgb(170, 190, 220), fa_center);
		break;
	}

	case MENU.SETTINGS: {
		// Tall enough that BACK (the last row, see set_y) sits well inside it.
		var _pw = 760, _ph = 670;
		var _px = _gw / 2 - _pw / 2, _py = _gh / 2 - 330;
		draw_set_colour(c_black);
		draw_rectangle(_px - 4, _py - 4, _px + _pw + 4, _py + _ph + 4, false);
		draw_set_colour(make_colour_rgb(70, 76, 100));
		draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
		draw_set_colour(make_colour_rgb(26, 30, 52));
		draw_rectangle(_px + 8, _py + 8, _px + _pw - 8, _py + _ph - 8, false);
		pixel_text(_gw / 2, _py + 30, "SETTINGS", 5, c_white, fa_center);
		var _r = global.resolutions[global.set_res];
		var _rows = [
			"RESOLUTION: " + string(_r[0]) + "X" + string(_r[1]),
			"FULLSCREEN: " + (global.set_fullscreen ? "ON" : "OFF"),
			"UI SCALE: " + string(round(global.ui_scales[global.set_ui] * 100)) + "%",
			"HUD: " + (global.set_hud ? "ON" : "OFF"),
			"MUSIC: " + string(global.set_music * 10) + "%",
			"SFX: " + string(global.set_sfx * 10) + "%",
			"BACK",
		];
		for (var _i = 0; _i < set_rows; _i++) {
			// Resolution only matters in a window, so it's locked and greyed out while fullscreen.
			var _state = (_i == 0 && global.set_fullscreen) ? 2 : ((_i == set_sel) ? 1 : 0);
			// Greyed-out resolution: its label moves up to make room for a note inside the box.
			var _note = _i == 0 && global.set_fullscreen;
			draw_pixel_button(set_x(), set_y(_i), set_w, btn_h, _note ? "" : _rows[_i], _state);
			if (_note) {
				pixel_text(set_x() + set_w / 2, set_y(_i) + 9, _rows[_i], 3, make_colour_rgb(90, 94, 110), fa_center);
				pixel_text(set_x() + set_w / 2, set_y(_i) + 39, "USED WHEN WINDOWED", 2, make_colour_rgb(110, 116, 136), fa_center);
			}
			if (_i < set_rows - 1) {
				// Arrows at each end, dimmed when the value can't go further that way.
				var _lo = true, _hi = true;
				if (_i == 0) { _lo = global.set_res > 0; _hi = global.set_res < array_length(global.resolutions) - 1; }
				if (_i == 2) { _lo = global.set_ui > 0; _hi = global.set_ui < array_length(global.ui_scales) - 1; }
				if (_i == 4) { _lo = global.set_music > 0; _hi = global.set_music < 10; }
				if (_i == 5) { _lo = global.set_sfx > 0; _hi = global.set_sfx < 10; }
				var _ay = set_y(_i) + btn_h / 2 - 12;
				var _on = make_colour_rgb(210, 216, 235), _off = make_colour_rgb(70, 76, 100);
				pixel_text(set_x() + 28, _ay, "<", 3, (_state != 2 && _lo) ? _on : _off, fa_center);
				pixel_text(set_x() + set_w - 28, _ay, ">", 3, (_state != 2 && _hi) ? _on : _off, fa_center);
			}
		}
		pixel_text(_gw / 2, _gh - 32, "W / S TO CHOOSE     A / D OR ENTER TO CHANGE     ESC: BACK", 2, make_colour_rgb(170, 190, 220), fa_center);
		break;
	}

	case MENU.ABOUT: {
		pixel_text(_gw / 2, _gh / 2 - 230, "ABOUT", 7, c_white, fa_center);
		var _txt = make_colour_rgb(210, 216, 235);
		pixel_text(_gw / 2, _gh / 2 - 125, "THIS GAME WAS MADE BY AZLAAN, UMER, AND MOHIB", 3, _txt, fa_center);
		pixel_text(_gw / 2, _gh / 2 - 88, "FOR NASCON 2026.", 3, _txt, fa_center);
		for (var _i = 0; _i < 2; _i++) {
			draw_pixel_button(btn_x(), btn_y(_i + 1), btn_w, btn_h, about_items[_i], (!trailer_open && _i == about_sel) ? 1 : 0);
		}
		pixel_text(_gw / 2, _gh - 60, "ENTER OR CLICK TO SELECT     ESC: BACK", 2, make_colour_rgb(170, 190, 220), fa_center);

		if (trailer_open) {
			// A framed window over the menu.
			draw_set_alpha(0.7);
			draw_set_colour(c_black);
			draw_rectangle(0, 0, _gw, _gh, false);
			draw_set_alpha(1);
			var _tx = trailer_x(), _ty = trailer_y(), _tw = trailer_w, _th = trailer_h;
			draw_set_colour(c_black);
			draw_rectangle(_tx - 10, _ty - 50, _tx + _tw + 10, _ty + _th + 10, false);
			draw_set_colour(make_colour_rgb(70, 76, 100));
			draw_rectangle(_tx - 6, _ty - 46, _tx + _tw + 6, _ty + _th + 6, false);
			draw_set_colour(make_colour_rgb(26, 30, 52));
			draw_rectangle(_tx, _ty - 40, _tx + _tw, _ty - 4, false);
			draw_set_colour(c_black);
			draw_rectangle(_tx, _ty, _tx + _tw, _ty + _th, false);
			pixel_text(_tx + 10, _ty - 34, "TRAILER", 3, c_white, fa_left);
			// Volume slider: a track, the filled part, and a knob.
			var _sl = trailer_slider();
			var _kx = _sl[0] + round(trailer_vol * _sl[2]);
			pixel_text(_sl[0] - 14, _sl[1] - 8, "VOL", 2, make_colour_rgb(170, 190, 220), fa_right);
			draw_set_colour(c_black);
			draw_rectangle(_sl[0] - 2, _sl[1] - 5, _sl[0] + _sl[2] + 2, _sl[1] + 5, false);
			draw_set_colour(make_colour_rgb(50, 54, 70));
			draw_rectangle(_sl[0], _sl[1] - 3, _sl[0] + _sl[2], _sl[1] + 3, false);
			draw_set_colour(make_colour_rgb(160, 180, 230));
			draw_rectangle(_sl[0], _sl[1] - 3, _kx, _sl[1] + 3, false);
			draw_set_colour(c_black);
			draw_rectangle(_kx - 7, _sl[1] - 11, _kx + 7, _sl[1] + 11, false);
			draw_set_colour(trailer_drag ? c_white : make_colour_rgb(210, 216, 235));
			draw_rectangle(_kx - 5, _sl[1] - 9, _kx + 5, _sl[1] + 9, false);
			// X button
			var _xb = trailer_xbtn();
			var _mx = device_mouse_x_to_gui(0), _my = device_mouse_y_to_gui(0);
			var _hot = point_in_rectangle(_mx, _my, _xb[0], _xb[1], _xb[0] + 30, _xb[1] + 30);
			draw_set_colour(_hot ? make_colour_rgb(200, 60, 70) : make_colour_rgb(120, 40, 50));
			draw_rectangle(_xb[0], _xb[1], _xb[0] + 30, _xb[1] + 30, false);
			pixel_text(_xb[0] + 15, _xb[1] + 4, "X", 3, c_white, fa_center);
			// The video frame, or a loading note until the first one is ready.
			var _v = video_draw();
			if (_v[0] == 0 && surface_exists(_v[1])) draw_surface_stretched(_v[1], _tx, _ty, _tw, _th);
			else pixel_text(_tx + _tw / 2, _ty + _th / 2 - 8, "LOADING...", 2, make_colour_rgb(170, 190, 220), fa_center);
			pixel_text(_gw / 2, _ty + _th + 24, "A / D OR DRAG: VOLUME     ESC OR X TO CLOSE", 2, make_colour_rgb(170, 190, 220), fa_center);
		}
		break;
	}

	case MENU.PAUSE: {
		pixel_text(_gw / 2, _gh / 2 - 200, "PAUSED", 7, c_white, fa_center);
		if (ISO_RANDOM_MAP) pixel_text(_gw / 2, _gh / 2 - 125, "MAP SEED: " + string(global.iso_seed), 2, make_colour_rgb(170, 190, 220), fa_center);
		for (var _i = 0; _i < array_length(pause_items); _i++) {
			draw_pixel_button(btn_x(), btn_y(_i), btn_w, btn_h, pause_items[_i], (_i == pause_sel) ? 1 : 0);
		}
		pixel_text(_gw / 2, _gh - 60, "ESC: RESUME     ENTER OR CLICK TO SELECT", 2, make_colour_rgb(170, 190, 220), fa_center);
		break;
	}

	case MENU.PLAYMODE: {
		pixel_text(_gw / 2, _gh / 2 - 200, "PLAY", 7, c_white, fa_center);
		for (var _i = 0; _i < array_length(mode_items); _i++) {
			var _it = mode_items[_i];
			var _state = !_it.enabled ? 2 : (_i == mode_sel ? 1 : 0);
			draw_pixel_button(btn_x(), btn_y(_i), btn_w, btn_h, _it.label, _state);
			// The reason it's greyed out goes just right of the button, clear of the label.
			if (!_it.enabled) pixel_text(btn_x() + btn_w + 20, btn_y(_i) + btn_h / 2 - 8, variable_struct_exists(_it, "note") ? _it.note : "SOON", 2, make_colour_rgb(150, 154, 170), fa_left);
		}
		pixel_text(_gw / 2, _gh - 60, "W / S OR MOUSE TO CHOOSE     ENTER OR CLICK TO SELECT     ESC: BACK", 2, make_colour_rgb(170, 190, 220), fa_center);
		break;
	}

	case MENU.LOBBY: {
		var _count = array_length(global.lobby_slots);
		pixel_text(_gw / 2, _gh / 2 - 330, lobby_joined ? ((global.net_mode == "steam") ? "ONLINE LOBBY" : "LAN LOBBY") : "HOST GAME", 5, c_white, fa_center);
		var _info = "PLAYERS: " + string(_count) + " / " + string(LOBBY_MAX);
		if (!lobby_joined && net_lan_open()) _info += "     OPEN TO LAN";
		if (!lobby_joined && net_online_open() && oNet.steam_lobby != 0) _info += "     OPEN ONLINE";
		if (lobby_joined) _info += global.net_in_match ? "     THE HOST IS IN A MATCH" : "     WAITING FOR THE HOST";
		pixel_text(_gw / 2, _gh / 2 - 275, _info, 2, make_colour_rgb(170, 190, 220), fa_center);
		var _dim = make_colour_rgb(90, 94, 110);
		for (var _i = 0; _i < LOBBY_MAX; _i++) {
			var _x = slot_x(_i), _y = slot_y(_i);
			var _filled = _i < _count;
			var _col = _filled ? global.body_colours[global.lobby_slots[_i]] : make_colour_rgb(50, 54, 70);
			draw_set_colour(c_black);
			draw_rectangle(_x - 4, _y - 4, _x + slot_w + 4, _y + slot_h + 4, false);
			draw_set_colour(_col);
			draw_rectangle(_x, _y, _x + slot_w, _y + slot_h, false);
			draw_set_colour(_filled ? make_colour_rgb(26, 30, 52) : make_colour_rgb(30, 32, 42));
			draw_rectangle(_x + 4, _y + 4, _x + slot_w - 4, _y + slot_h - 4, false);
			pixel_text(_x + 16, _y + 16, "P" + string(_i), 2, _filled ? c_white : _dim, fa_left);
			if (!_filled) {
				pixel_text(_x + 106, _y + 16, "EMPTY", 2, _dim, fa_left);
				continue;
			}
			draw_pixel_star(_x + 62, _y + 11, 3, _col, c_black, true);
			var _kind = global.lobby_kind[_i];
			var _nm = (_i < array_length(global.lobby_names)) ? global.lobby_names[_i] : "";   // Steam names, online
			var _name = (_i == lobby_me()) ? "YOU" : ((_nm != "") ? string_copy(_nm, 1, 6) : ((_kind == "host") ? "HOST" : ((_kind == "player") ? "PLAYER" : "DUMMY")));
			pixel_text(_x + 106, _y + 16, _name, 2, c_white, fa_left);
			pixel_text(_x + 180, _y + 16, global.body_colour_names[global.lobby_slots[_i]], 2, _col, fa_left);
		}
		for (var _i = 0; _i < 4; _i++) {
			var _state = !lobby_enabled(_i) ? 2 : (_i == lobby_sel ? 1 : 0);
			draw_pixel_button(lobby_btn_x(_i), lobby_btn_y(), lobby_btn_w, btn_h, lobby_items[_i], _state, false);
		}
		if (lobby_joined) {
			pixel_text(_gw / 2, lan_btn_y() + 20, "ONLY THE HOST CAN START THE MATCH", 2, make_colour_rgb(170, 190, 220), fa_center);
			pixel_text(_gw / 2, _gh - 36, "YOU PICK YOUR POWER WHEN THE MATCH STARTS     ESC: LEAVE", 2, make_colour_rgb(170, 190, 220), fa_center);
		} else {
			var _labels = lobby_net_labels();
			for (var _k = 0; _k < 3; _k++) {
				var _st = !lobby_enabled(4 + _k) ? 2 : ((lobby_sel == 4 + _k) ? 1 : 0);
				draw_pixel_button(lan_btn_x(_k), lan_btn_y(), lan_btn_w, btn_h, _labels[_k], _st, false);
			}
			if (global.net_status != "") pixel_text(_gw / 2, lan_btn_y() + btn_h + 8, global.net_status, 2, net_is_open() ? make_colour_rgb(170, 190, 220) : make_colour_rgb(240, 150, 150), fa_center);
			pixel_text(_gw / 2, _gh - 36, "A / D: BUTTONS     ESC: BACK", 2, make_colour_rgb(170, 190, 220), fa_center);
		}
		break;
	}

	case MENU.JOIN: {
		pixel_text(_gw / 2, _gh / 2 - 300, join_online ? "JOIN ONLINE" : "JOIN LAN", 5, c_white, fa_center);
		pixel_text(_gw / 2, _gh / 2 - 236, global.net_status, 2, make_colour_rgb(170, 190, 220), fa_center);
		var _items = join_items();
		for (var _i = 0; _i < array_length(_items); _i++) {
			draw_pixel_button(join_x(), join_y(_i), join_w, btn_h, _items[_i].label, (_i == join_sel) ? 1 : 0);
		}
		pixel_text(_gw / 2, _gh - 36, "W / S OR MOUSE TO CHOOSE     ENTER OR CLICK TO JOIN     ESC: BACK", 2, make_colour_rgb(170, 190, 220), fa_center);
		break;
	}
}
draw_set_colour(c_white);
