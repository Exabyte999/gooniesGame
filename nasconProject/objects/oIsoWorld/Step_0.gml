// Music, fades and the bus effects (see Audio in scr_iso).
audio_step();

// Back in the window after alt-tab: forget keys and buttons Windows left "held" while we
// were away, and fit the view to the window again in case alt-tab changed its size.
var _focus = window_has_focus();
if (_focus && !had_focus) {
	io_clear();
	if (global.set_fullscreen != window_get_fullscreen()) settings_apply(); else settings_apply_view();
}
had_focus = _focus;

build_pick_step();   // the build pick screen before a match

hover_gx = screen_to_tile_x(mouse_x, mouse_y);
hover_gy = screen_to_tile_y(mouse_x, mouse_y);

for (var _i = 0; _i < array_length(clouds); _i++) {
	var _c = clouds[_i];
	_c.cx += _c.spd;
	if (_c.cx > global.iso_origin_x + CLOUD_SPAN) _c.cx -= 2 * CLOUD_SPAN;
}

// Crumbled tiles drop away and fade out.
for (var _i = array_length(global.iso_falling) - 1; _i >= 0; _i--) {
	var _f = global.iso_falling[_i];
	_f.vy += 0.35;
	_f.dy += _f.vy;
	_f.alpha -= 0.015;
	if (_f.alpha <= 0) {
		global.iso_fall[_f.gx][_f.gy] = -1;
		array_delete(global.iso_falling, _i, 1);
	}
}

// Esc opens the pause menu over the match. The game keeps running (see oIsoMenu).
var _me = iso_local_player();
if (!global.menu_open && !global.pause_open && instance_exists(_me) && _me.input.pause) {
	global.menu_pausing = true;
	instance_create_depth(0, 0, -10000, oIsoMenu);
}
if (global.menu_open) exit;

// Last one standing wins, then back to the lobby (see match_step). Joined over LAN,
// the host decides that and sends it with its snapshots.
if (!global.net_client_match) {
	match_step();
	// TEMP: F1 drops a dummy on a random open inner tile (see iso_spawn_dummy).
	if (keyboard_check_pressed(vk_f1)) iso_spawn_dummy();
}

// Burning tiles count down, cracking as they go, then crumble.
for (var _gx = 0; _gx < global.iso_w; _gx++) {
	for (var _gy = 0; _gy < global.iso_h; _gy++) {
		if (global.iso_burn[_gx][_gy] <= 0) continue;
		global.iso_burn[_gx][_gy]--;
		if (!iso_has_floor(_gx, _gy)) { global.iso_burn[_gx][_gy] = 0; continue; }
		global.iso_hp[_gx][_gy] = max(1, ceil(ISO_TILE_HP * global.iso_burn[_gx][_gy] / ISO_BURN_FRAMES));
		// The crumble sound (1.3 s) starts here so it ends just after the tile drops away.
		if (global.iso_burn[_gx][_gy] == CRUMBLE_SOUND_LEAD) sfx_play(snd_crumble, -3, 0.06);
		if (global.iso_burn[_gx][_gy] == 0) iso_crumble_tile(_gx, _gy);
	}
}
