// Isometric helpers shared by the whole template.
// Grid coords (gx, gy) are tiles; screen coords are room pixels.
// iso_to_screen_* returns the CENTRE of a tile's diamond.

#macro ISO_TILE_W 64
#macro ISO_TILE_H 32
#macro ISO_HALF_W (ISO_TILE_W / 2)
#macro ISO_HALF_H (ISO_TILE_H / 2)

// Room position of tile (0, 0). oIsoWorld sets these when the map loads.
global.iso_origin_x = 0;
global.iso_origin_y = 0;

// Map data, filled by oIsoWorld. iso_floor[gx][gy] is a sIsoTile frame or -1 for no floor.
global.iso_w = 0;
global.iso_h = 0;
global.iso_floor = [];
global.iso_solid = [];

function iso_to_screen_x(_gx, _gy) {
	return global.iso_origin_x + (_gx - _gy) * ISO_HALF_W;
}

function iso_to_screen_y(_gx, _gy) {
	return global.iso_origin_y + (_gx + _gy) * ISO_HALF_H;
}

// Fractional grid position under a screen point.
function screen_to_iso_x(_sx, _sy) {
	var _a = (_sx - global.iso_origin_x) / ISO_HALF_W;
	var _b = (_sy - global.iso_origin_y) / ISO_HALF_H;
	return (_a + _b) / 2;
}

function screen_to_iso_y(_sx, _sy) {
	var _a = (_sx - global.iso_origin_x) / ISO_HALF_W;
	var _b = (_sy - global.iso_origin_y) / ISO_HALF_H;
	return (_b - _a) / 2;
}

// Whole tile under a screen point (e.g. the mouse).
function screen_to_tile_x(_sx, _sy) {
	return floor(screen_to_iso_x(_sx, _sy) + 0.5);
}

function screen_to_tile_y(_sx, _sy) {
	return floor(screen_to_iso_y(_sx, _sy) + 0.5);
}

// Depth for something standing on a tile. Tiles further down the screen
// (larger gx + gy) get a lower depth, so they draw in front.
function iso_depth(_gx, _gy) {
	return -(_gx + _gy) * 100;
}

function iso_in_bounds(_gx, _gy) {
	return _gx >= 0 && _gy >= 0 && _gx < global.iso_w && _gy < global.iso_h;
}

function iso_walkable(_gx, _gy) {
	if (!iso_in_bounds(_gx, _gy)) return false;
	return global.iso_floor[_gx][_gy] != -1 && !global.iso_solid[_gx][_gy];
}

// Breadth-first search over walkable tiles (4-way).
// Returns an array of [gx, gy] steps, not including the start, or [] if unreachable.
function iso_find_path(_sx, _sy, _tx, _ty) {
	if (!iso_walkable(_tx, _ty) || (_sx == _tx && _sy == _ty)) return [];

	var _w = global.iso_w;
	var _came = array_create(_w * global.iso_h, -1);
	var _start = _sx + _sy * _w;
	var _goal = _tx + _ty * _w;
	var _dirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
	var _queue = ds_queue_create();

	_came[_start] = _start;
	ds_queue_enqueue(_queue, _start);

	while (!ds_queue_empty(_queue)) {
		var _cur = ds_queue_dequeue(_queue);
		if (_cur == _goal) break;
		var _cx = _cur mod _w;
		var _cy = _cur div _w;
		for (var _i = 0; _i < 4; _i++) {
			var _nx = _cx + _dirs[_i][0];
			var _ny = _cy + _dirs[_i][1];
			if (!iso_walkable(_nx, _ny)) continue;
			var _n = _nx + _ny * _w;
			if (_came[_n] != -1) continue;
			_came[_n] = _cur;
			ds_queue_enqueue(_queue, _n);
		}
	}
	ds_queue_destroy(_queue);

	if (_came[_goal] == -1) return [];

	var _path = [];
	var _node = _goal;
	while (_node != _start) {
		array_insert(_path, 0, [_node mod _w, _node div _w]);
		_node = _came[_node];
	}
	return _path;
}

// True if every tile within _r steps (a square ring) of (_gx, _gy) has ground.
function iso_land_ring(_gx, _gy, _r) {
	for (var _i = -_r; _i <= _r; _i++) {
		for (var _j = -_r; _j <= _r; _j++) {
			if (max(abs(_i), abs(_j)) != _r) continue;
			var _x = _gx + _i, _y = _gy + _j;
			if (!iso_in_bounds(_x, _y) || global.iso_floor[_x][_y] == -1) return false;
		}
	}
	return true;
}

// ---------- Tile damage and crumbling ----------
#macro ISO_TILE_HP 6

global.shake = 0;          // camera shake in pixels, fades out each frame
global.iso_hp = [];        // health left on each tile
global.iso_prop = [];      // the tree or boulder standing on each tile, or noone
global.iso_fall = [];      // per tile: its falling chunk while it drops away, else -1
global.iso_falling = [];   // every chunk that is currently falling
global.iso_under = [];     // how many rock chunks hang under each tile

// Rock under each tile grows with the distance to the front edges (+gx, +gy),
// which gives the underside its soft V. Rebuilt whenever a tile crumbles, so
// the ground around a new hole thins out like a fresh edge.
function iso_build_under() {
	global.iso_under = array_create(global.iso_w);
	for (var _gx = 0; _gx < global.iso_w; _gx++) {
		global.iso_under[_gx] = array_create(global.iso_h, 0);
		for (var _gy = 0; _gy < global.iso_h; _gy++) {
			if (global.iso_floor[_gx][_gy] == -1) continue;
			var _a = 1;
			while (_a < 5 && iso_has_floor(_gx + _a, _gy)) _a++;
			var _b = 1;
			while (_b < 5 && iso_has_floor(_gx, _gy + _b)) _b++;
			global.iso_under[_gx][_gy] = min(_a, _b) * 3 - 2 + ((_gx * 7 + _gy * 13) mod 2);
		}
	}
}

function iso_has_floor(_gx, _gy) {
	return iso_in_bounds(_gx, _gy) && global.iso_floor[_gx][_gy] != -1;
}

// Knock _amount of health off a tile. At zero it crumbles away.
function iso_damage_tile(_gx, _gy, _amount) {
	if (!iso_has_floor(_gx, _gy)) return;
	global.iso_hp[_gx][_gy] -= _amount;
	if (global.iso_hp[_gx][_gy] <= 0) iso_crumble_tile(_gx, _gy);
}

// Crumbling goes through the event log (see game_event), which then calls the _apply version.
function iso_crumble_tile(_gx, _gy) {
	if (!iso_has_floor(_gx, _gy)) return;
	game_event("tile_crumble", { gx: _gx, gy: _gy });
}

function iso_crumble_tile_apply(_gx, _gy) {
	if (!iso_has_floor(_gx, _gy)) return;
	var _chunk = {
		gx: _gx, gy: _gy,
		tile: global.iso_floor[_gx][_gy],
		under: global.iso_under[_gx][_gy],
		dy: 0, vy: -1.5, alpha: 1,
	};
	global.iso_fall[_gx][_gy] = _chunk;
	array_push(global.iso_falling, _chunk);
	global.iso_floor[_gx][_gy] = -1;
	global.iso_solid[_gx][_gy] = false;
	global.iso_hp[_gx][_gy] = 0;

	// Whatever stood here falls with it and frees every tile it covered.
	var _prop = global.iso_prop[_gx][_gy];
	if (instance_exists(_prop)) {
		var _cells = _prop.cells;
		for (var _i = 0; _i < array_length(_cells); _i++) {
			var _cx = _cells[_i][0];
			var _cy = _cells[_i][1];
			if (!iso_in_bounds(_cx, _cy)) continue;
			global.iso_prop[_cx][_cy] = noone;
			if (global.iso_floor[_cx][_cy] != -1) global.iso_solid[_cx][_cy] = false;
		}
		_prop.falling = true;
	}

	iso_build_under();
	global.shake = max(global.shake, 5);
}

// ---------- Builds ----------
// Each player picks one build on the start menu.
enum BUILD { FIRE = 0, SHADOW = 1, TIME = 2 }
#macro ISO_BURN_FRAMES 180   // a burning tile crumbles after this many frames
#macro CRUMBLE_SOUND_LEAD 70  // frames before a burning tile crumbles that snd_crumble starts

global.build = -1;           // chosen build, -1 until the menu closes
global.menu_open = true;
global.pause_open = false;   // the pause menu is up, but the game keeps running underneath
global.iso_burn = [];        // frames left on each burning tile, 0 = not burning
global.pixel_font_id = -1;

// The chunky pixel font used by the menu and HUD (sPixelFont, monospace, capitals).
function pixel_font() {
	if (global.pixel_font_id == -1) {
		global.pixel_font_id = font_add_sprite_ext(sPixelFont, " !%'()+,-./0123456789:<>?ABCDEFGHIJKLMNOPQRSTUVWXYZ", false, 0);
	}
	return global.pixel_font_id;
}

// Draw text with the pixel font at a whole-number scale.
function pixel_text(_x, _y, _str, _scale, _col, _halign) {
	draw_set_font(pixel_font());
	draw_set_halign(_halign);
	draw_set_valign(fa_top);
	draw_set_colour(c_black);
	draw_text_transformed(_x + _scale, _y + _scale, string_upper(_str), _scale, _scale, 0);
	draw_set_colour(_col);
	draw_text_transformed(_x, _y, string_upper(_str), _scale, _scale, 0);
	draw_set_halign(fa_left);
}

// Set a tile on fire. It cracks as it burns and crumbles when the fire is out.
// _by is the player number that lit it, or -1.
function iso_ignite_tile(_gx, _gy, _by = -1) {
	if (!iso_has_floor(_gx, _gy) || global.iso_burn[_gx][_gy] > 0) return;
	game_event("tile_ignite", { gx: _gx, gy: _gy, by: _by });
}

// ---------- Bodies: knockback shared by players and the dummy ----------
// Call body_init(is_local) in a Create event once fx, fy and radius are set, and
// body_knock_step() every Step before the floor check. Whatever runs these
// slides with the same physics, and can be knocked clean off the island.
#macro KNOCK_FRICTION 0.86     // speed kept each frame while sliding
#macro KNOCK_STUN 20           // frames of weak control after a hit
#macro KILL_CREDIT 300         // a fall within 5 seconds of a hit counts as that player's kill

// Colours players can be given. Every body gets a different one.
// 16 colours picked to be as easy to tell apart as possible (based on Sasha Trubetskoy's
// list of distinct colours), skipping the ones too dark to read on the HUD.
global.body_colours = [
	make_colour_rgb(230, 25, 75),    // red
	make_colour_rgb(60, 180, 75),    // green
	make_colour_rgb(255, 225, 25),   // yellow
	make_colour_rgb(67, 99, 216),    // blue
	make_colour_rgb(245, 130, 49),   // orange
	make_colour_rgb(145, 30, 180),   // purple
	make_colour_rgb(66, 212, 244),   // cyan
	make_colour_rgb(240, 50, 230),   // magenta
	make_colour_rgb(191, 239, 69),   // lime
	make_colour_rgb(250, 190, 212),  // pink
	make_colour_rgb(70, 153, 144),   // teal
	make_colour_rgb(220, 190, 255),  // lavender
	make_colour_rgb(154, 99, 36),    // brown
	make_colour_rgb(128, 0, 0),      // maroon
	make_colour_rgb(128, 128, 0),    // olive
	make_colour_rgb(255, 255, 255),  // white
];
global.body_colour_names = ["RED", "GREEN", "YELLOW", "BLUE", "ORANGE", "PURPLE", "CYAN", "MAGENTA", "LIME", "PINK", "TEAL", "LAVENDER", "BROWN", "MAROON", "OLIVE", "WHITE"];

// _local: true for the player at this keyboard (their stars are drawn bold).
function body_init(_local) {
	kvx = 0;            // knockback velocity, tiles per frame
	kvy = 0;
	knock_timer = 0;    // frames left of weak control
	hit_flash = 0;      // frames left of the white hit flash
	is_local = _local;
	lives_max = 3;
	lives_left = lives_max;   // not "lives": that name is a GameMaker built-in global
	lives_pop = 0;      // frames left of the "-1" that rises when a life is lost
	eliminated = false; // out of stars: gone for the rest of the match
	last_hit_by = noone;   // who whipped this body last, for the kill feed
	last_hit_timer = 0;    // frames that hit still counts as the kill
	input = input_new();   // this frame's controls (see Input)
	// LAN (see LAN below). On the host, a joiner's player has their connection in net_sock and
	// is steered by net_in, the input their game sends. On a joiner's game every body is a
	// puppet that just follows the host's snapshots, sliding between them (net_p* to net_n*).
	if (!variable_instance_exists(id, "net_puppet")) net_puppet = false;
	if (!variable_instance_exists(id, "net_sock")) net_sock = -1;
	net_in = input_new();
	net_t = -1;           // frames since the last snapshot, -1 before the first
	// Particles (see Particles): the ability circle and aura, and the kill sparks.
	ab_fx_t = -1;         // frames into the ability effect, -1 when none
	ab_fx_build = 0;
	kill_fx_left = 0;     // frames left of sparking after a kill
	kill_fx = [];         // live sparks { ox, oy, t } around the body
	fx_last_tick = -1;
	net_px = 0; net_py = 0; net_pd = 0;
	net_nx = 0; net_ny = 0; net_nd = 0;
	// Player number: the host is 0, lobby slots 2-10 are 1-9. Fixed for the match, and what
	// co-op will use to tell players apart. Passed in as player_id, or the lowest free one.
	if (!variable_instance_exists(id, "player_id") || player_id < 0) {
		player_id = _local ? 0 : -1;
		if (!_local) {
			var _used = [];
			var _all = iso_bodies();
			for (var _b = 0; _b < array_length(_all); _b++) {
				var _o = _all[_b];
				if (_o != id && variable_instance_exists(_o, "player_id")) array_push(_used, _o.player_id);
			}
			player_id = 1;
			while (array_contains(_used, player_id)) player_id++;
		}
	}

	// A random colour no other body has yet. It tints the sprite and the HUD stars.
	var _free = [];
	var _bodies = iso_bodies();
	for (var _c = 0; _c < array_length(global.body_colours); _c++) {
		var _taken = false;
		for (var _b = 0; _b < array_length(_bodies); _b++) {
			var _o = _bodies[_b];
			if (_o != id && variable_instance_exists(_o, "body_col") && _o.body_col == global.body_colours[_c]) _taken = true;
		}
		if (!_taken) array_push(_free, _c);
	}
	if (array_length(_free) > 0) {
		var _pick = _free[irandom(array_length(_free) - 1)];
		body_col = global.body_colours[_pick];
		body_name = global.body_colour_names[_pick];
	} else {
		body_col = make_colour_hsv(irandom(255), 200, 240);
		body_name = "PLAYER";
	}
	body_tint = merge_colour(c_white, body_col, 0.6);   // softer, so the sprite's shading still shows
	// A colour picked in the lobby wins (passed in as colour_idx when the body is created).
	if (variable_instance_exists(id, "colour_idx") && colour_idx >= 0) body_set_colour(colour_idx);
}

// "P#" in the player's colour just below their feet (Draw End, so nothing hides it).
function body_draw_tag() {
	if (!global.set_hud || eliminated || (falling && fall_dy > 0)) return;   // hidden with the HUD
	pixel_text(x, y + 8, "P" + string(player_id), 1.5, body_col, fa_center);
	draw_set_colour(c_white);
}

// Give this body palette colour _idx.
function body_set_colour(_idx) {
	body_col = global.body_colours[_idx];
	body_name = global.body_colour_names[_idx];
	body_tint = merge_colour(c_white, body_col, 0.6);
}

// Drop a dummy on a random open tile that isn't on the edge of the island, a burning
// tile, or right next to anyone. _colour_idx -1 gives it any free colour.
function iso_spawn_dummy(_colour_idx = -1, _player_id = -1) {
	return iso_spawn_body(oIsoDummy, { colour_idx: _colour_idx, player_id: _player_id });
}

// The same, for any body (a LAN player is an oIsoPlayer). _vars are passed to its Create.
function iso_spawn_body(_obj, _vars = {}) {
	var _spots = [];
	var _bodies = iso_bodies();
	for (var _gx = 1; _gx < global.iso_w - 1; _gx++) {
		for (var _gy = 1; _gy < global.iso_h - 1; _gy++) {
			if (!iso_walkable(_gx, _gy) || global.iso_burn[_gx][_gy] > 0) continue;
			var _ok = true;
			for (var _u = -1; _u <= 1 && _ok; _u++) {
				for (var _v = -1; _v <= 1; _v++) {
					if (global.iso_floor[_gx + _u][_gy + _v] == -1) { _ok = false; break; }
				}
			}
			for (var _b = 0; _b < array_length(_bodies) && _ok; _b++) {
				var _o = _bodies[_b];
				if (point_distance(_gx, _gy, _o.fx, _o.fy) < 1.5) _ok = false;
			}
			if (_ok) array_push(_spots, [_gx, _gy]);
		}
	}
	if (array_length(_spots) == 0) return noone;
	var _s = _spots[irandom(array_length(_spots) - 1)];
	_vars.gx = _s[0];
	_vars.gy = _s[1];
	return instance_create_depth(0, 0, 0, _obj, _vars);
}

// ---------- Lobby ----------
// Slot 0 is the host, the rest are dummies or players who joined over LAN. Each slot holds
// a palette colour index, rolled when the slot is filled. Kept between matches. The host
// owns the lobby; joiners get a copy whenever it changes (see LAN).
#macro LOBBY_MAX 12
global.lobby_slots = [];
global.lobby_builds = [];    // each slot's build (BUILD.FIRE, SHADOW or TIME)
global.lobby_kind = [];      // "host", "dummy" or "player" (someone who joined over LAN)
global.lobby_sock = [];      // host only: each joined player's connection (a socket, or a Steam ID online), else -1
global.lobby_names = [];     // Steam names, online ("" on LAN and for dummies)

function lobby_free_colour() {
	var _free = [];
	// The lobby uses the first 12 colours, the most distinct ones. The rest are for F1 dummies.
	for (var _c = 0; _c < min(LOBBY_MAX, array_length(global.body_colours)); _c++) {
		if (!array_contains(global.lobby_slots, _c)) array_push(_free, _c);
	}
	return (array_length(_free) > 0) ? _free[irandom(array_length(_free) - 1)] : 0;
}

// Fill the next free slot. The first one is always the host. Returns the slot, or -1 if full.
function lobby_add(_kind = "dummy", _sock = -1, _name = "") {
	if (array_length(global.lobby_slots) >= LOBBY_MAX) return -1;
	var _first = array_length(global.lobby_slots) == 0;
	array_push(global.lobby_builds, _first ? BUILD.FIRE : irandom(2));   // others start on a random build
	array_push(global.lobby_slots, lobby_free_colour());
	array_push(global.lobby_kind, _first ? "host" : _kind);
	array_push(global.lobby_sock, _sock);
	array_push(global.lobby_names, _name);
	net_lobby_changed();
	return array_length(global.lobby_slots) - 1;
}

// Empty slot _i. Everyone after it moves up one (and takes that player number).
function lobby_remove_at(_i) {
	if (_i < 1 || _i >= array_length(global.lobby_slots)) return;
	array_delete(global.lobby_slots, _i, 1);
	array_delete(global.lobby_builds, _i, 1);
	array_delete(global.lobby_kind, _i, 1);
	array_delete(global.lobby_sock, _i, 1);
	array_delete(global.lobby_names, _i, 1);
	net_lobby_changed();
}

// The last dummy, or -1 if there are none (LAN players aren't removed this way).
function lobby_last_dummy() {
	for (var _i = array_length(global.lobby_slots) - 1; _i >= 1; _i--) if (global.lobby_kind[_i] == "dummy") return _i;
	return -1;
}

function lobby_remove() {
	lobby_remove_at(lobby_last_dummy());
}

// Step slot _i's build one way or the other.
function lobby_cycle_build(_i, _dir) {
	if (_i < 0 || _i >= array_length(global.lobby_builds)) return;
	global.lobby_builds[_i] = (global.lobby_builds[_i] + _dir + 3) mod 3;
	net_lobby_changed();
}

// The slot that's you: 0 when hosting, whatever the host gave you when joined.
function lobby_me() {
	return (global.net_role == "client") ? global.net_my_slot : 0;
}

// Can you change slot _i's build? Yours, and the host can set the dummies'.
function lobby_can_edit(_i) {
	if (global.net_role == "client") return _i == global.net_my_slot;
	return global.lobby_kind[_i] != "player";
}

// Change your own build: directly when hosting, by asking the host when joined.
function lobby_cycle_mine(_dir) {
	if (global.net_role == "client") net_client_send({ t: "build", dir: _dir });
	else lobby_cycle_build(0, _dir);
}

// Lose a star after falling off, and post it to the kill feed. At 0 stars you're eliminated.
// The kill goes to whoever whipped you within the last few seconds.
function body_lose_life() {
	var _killer = (last_hit_timer > 0 && instance_exists(last_hit_by)) ? last_hit_by.player_id : -1;
	game_event("life_lost", { victim: player_id, by: _killer, x: fx, y: fy });
}

// Push this body away from (_from_x, _from_y). _force is the starting speed in tiles per frame.
// _by is whoever made the hit, so a fall right after counts as their kill.
function body_knock(_from_x, _from_y, _force, _by = noone) {
	game_event("hit", {
		victim: player_id, by: instance_exists(_by) ? _by.player_id : -1,
		x: fx, y: fy, from_x: _from_x, from_y: _from_y, force: _force,
	});
}

function body_knock_apply(_from_x, _from_y, _force, _by = noone) {
	if (_by != noone) {
		last_hit_by = _by;
		last_hit_timer = KILL_CREDIT;
	}
	// Time: a hit that starts a slide remembers where you stood, for the rewind (see rewind_target).
	if (variable_instance_exists(id, "prehit_tick") && abs(kvx) + abs(kvy) < 0.05 && !falling) {
		prehit_tick = hist_tick;
		prehit_x = fx;
		prehit_y = fy;
	}
	var _dx = fx - _from_x, _dy = fy - _from_y;
	var _d = point_distance(0, 0, _dx, _dy);
	if (_d < 0.01) { _dx = 1; _dy = 0; _d = 1; }
	kvx += _dx / _d * _force;
	kvy += _dy / _d * _force;
	knock_timer = KNOCK_STUN;
	hit_flash = 8;
}

// Only trees and boulders stop a slide. Empty sky doesn't, so you can be knocked off the edge.
function body_clear(_x, _y) {
	for (var _i = 0; _i < 4; _i++) {
		var _cx = floor(_x + ((_i mod 2) ? radius : -radius) + 0.5);
		var _cy = floor(_y + ((_i div 2) ? radius : -radius) + 0.5);
		if (iso_in_bounds(_cx, _cy) && global.iso_solid[_cx][_cy]) return false;
	}
	return true;
}

function body_knock_step() {
	if (abs(kvx) + abs(kvy) < 0.005) {
		kvx = 0;
		kvy = 0;
	} else {
		// Bounce off trees and boulders a little.
		if (body_clear(fx + kvx, fy)) fx += kvx; else kvx *= -0.3;
		if (body_clear(fx, fy + kvy)) fy += kvy; else kvy *= -0.3;
		kvx *= KNOCK_FRICTION;
		kvy *= KNOCK_FRICTION;
	}
	if (knock_timer > 0) knock_timer--;
	if (last_hit_timer > 0) last_hit_timer--;
	if (hit_flash > 0) hit_flash--;
}

// Start falling. Nothing is forced: you just keep the speed you had and gravity takes over.
#macro FALL_COMMIT 10          // pixels below the ground before you can't land any more
function body_start_fall() {
	falling = true;
	fall_timer = 0;
	fall_vy = 0;
}

// Each frame of a fall: momentum carries you on while gravity pulls you down.
// If you're moving fast enough to cross a gap before you sink below the ground,
// you land on the far side, so a quick slide skims over a small hole and a slow one drops in.
function body_fall_step() {
	fx += kvx;
	fy += kvy;
	kvx *= 0.97;          // less drag in the air than sliding on grass
	kvy *= 0.97;
	fall_vy += 0.4;
	fall_dy += fall_vy;
	fall_timer++;
	x = iso_to_screen_x(fx, fy);
	y = iso_to_screen_y(fx, fy);
	depth = -(fx + fy) * 100 - 50;
	if (fall_dy < FALL_COMMIT && iso_has_floor(floor(fx + 0.5), floor(fy + 0.5)) && body_clear(fx, fy)) {
		falling = false;
		fall_dy = 0;
		fall_vy = 0;
		fall_timer = 0;
	}
}

// Everything a chain can knock back.
function iso_bodies() {
	var _a = [];
	with (oIsoPlayer) array_push(_a, id);
	with (oIsoDummy) array_push(_a, id);
	return _a;
}

// ---------- Settings: video, HUD and volume (saved to settings.ini next to the game's save data) ----------
#macro GUI_W 1366               // menus and HUD are laid out for this width and scale with the window
global.resolutions = [[1280, 720], [1366, 768], [1600, 900], [1920, 1080]];
global.set_res = 1;             // index into global.resolutions, used when windowed
global.set_fullscreen = false;
global.ui_scales = [0.5, 0.75, 1, 1.1];    // above 110% the menus stop fitting the screen
global.set_ui = 2;              // index into global.ui_scales, 1 = 100%
global.set_hud = true;          // the match HUD (stars, kill feed, build bar, help text); the countdown and win screen always show
global.set_music = 10;          // music volume in tenths, 0 to 10 (100%): the songs and the wind, on top of their own mix levels
global.set_sfx = 10;            // sound effects volume in tenths, the same way: everything played with sfx_play, menu clicks included
global.settings_loaded = false;

function settings_load() {
	ini_open("settings.ini");
	global.set_res = clamp(ini_read_real("video", "resolution", 1), 0, array_length(global.resolutions) - 1);
	global.set_fullscreen = ini_read_real("video", "fullscreen", 0) == 1;
	global.set_ui = clamp(ini_read_real("video", "ui_scale", 2), 0, array_length(global.ui_scales) - 1);
	global.set_hud = ini_read_real("video", "hud", 1) == 1;
	var _old = ini_read_real("audio", "volume", 10);   // the single VOLUME from before carries over to both
	global.set_music = clamp(round(ini_read_real("audio", "music", _old)), 0, 10);
	global.set_sfx = clamp(round(ini_read_real("audio", "sfx", _old)), 0, 10);
	ini_close();
	settings_apply_volume();
}

function settings_save() {
	ini_open("settings.ini");
	ini_write_real("video", "resolution", global.set_res);
	ini_write_real("video", "fullscreen", global.set_fullscreen ? 1 : 0);
	ini_write_real("video", "ui_scale", global.set_ui);
	ini_write_real("video", "hud", global.set_hud ? 1 : 0);
	ini_write_real("audio", "music", global.set_music);
	ini_write_real("audio", "sfx", global.set_sfx);
	ini_close();
}

// Music is scaled every frame in aud_track_step and effects in sfx_play, so this only
// undoes the old single master volume.
function settings_apply_volume() {
	audio_master_gain(1);
}

// The size the game draws at: the whole screen in fullscreen, otherwise the chosen resolution.
function settings_render_size() {
	if (global.set_fullscreen) return [display_get_width(), display_get_height()];
	return global.resolutions[global.set_res];
}

// Resize the window (or go fullscreen) and match the view and GUI to it.
function settings_apply() {
	window_set_fullscreen(global.set_fullscreen);
	if (!global.set_fullscreen) {
		var _r = global.resolutions[global.set_res];
		window_set_size(_r[0], _r[1]);
		call_later(2, time_source_units_frames, window_center);
	}
	settings_apply_view();
}

// The game draws at full window resolution; the camera and GUI keep their layout
// and only change height to match the screen's shape, so nothing gets stretched.
function settings_apply_view() {
	var _s = settings_render_size();
	view_wport[0] = _s[0];
	view_hport[0] = _s[1];
	surface_resize(application_surface, _s[0], _s[1]);
	// UI scale: a smaller scale lays the GUI out on a bigger canvas, so everything on it shrinks.
	var _gw = GUI_W / global.ui_scales[global.set_ui];
	display_set_gui_size(round(_gw), round(_gw * _s[1] / _s[0]));
}

// ---------- Lives HUD: a row of stars per player, top right ----------
// 9x9 pixel star. # body, h highlight (top left, lit side), s shade (bottom right), w sparkle.
global.star_rows = [
	"....h....",
	"...hw#...",
	"...h##...",
	"hhhh###ss",
	".hh####s.",
	"..h###s..",
	"..h#.#s..",
	".h#...#s.",
	".#.....s.",
];

// Building a star is a few hundred rectangles, so each look (size, colours, sparkle) is
// drawn once into a sprite and reused. Without this, many players tanked the frame rate.
global.star_cache = {};
function draw_pixel_star(_x, _y, _u, _fill, _outline, _sparkle) {
	var _key = string(_u) + "_" + string(_fill) + "_" + string(_outline) + "_" + string(_sparkle);
	var _spr = global.star_cache[$ _key];
	if (is_undefined(_spr) || !sprite_exists(_spr)) {
		var _size = 11 * _u;   // 9 pixels plus a 1 pixel outline each side
		var _surf = surface_create(_size, _size);
		surface_set_target(_surf);
		draw_clear_alpha(c_black, 0);
		draw_set_alpha(1);
		draw_pixel_star_raw(_u, _u, _u, _fill, _outline, _sparkle);
		surface_reset_target();
		_spr = sprite_create_from_surface(_surf, 0, 0, _size, _size, false, false, 0, 0);
		surface_free(_surf);
		global.star_cache[$ _key] = _spr;
	}
	draw_sprite(_spr, 0, _x - _u, _y - _u);
}

function draw_pixel_star_raw(_x, _y, _u, _fill, _outline, _sparkle) {
	var _lit = merge_colour(_fill, c_white, 0.45);
	var _dark = merge_colour(_fill, c_black, 0.35);
	var _spark = _sparkle ? c_white : _lit;
	// Outline first (the star nudged one pixel each way), then the shaded fill on top.
	for (var _pass = 0; _pass < 5; _pass++) {
		var _ox = [-1, 1, 0, 0, 0][_pass] * _u, _oy = [0, 0, -1, 1, 0][_pass] * _u;
		for (var _r = 0; _r < 9; _r++) {
			var _row = global.star_rows[_r];
			for (var _c = 0; _c < 9; _c++) {
				var _ch = string_char_at(_row, _c + 1);
				if (_ch == ".") continue;
				var _col = _fill;
				if (_ch == "h") _col = _lit;
				else if (_ch == "s") _col = _dark;
				else if (_ch == "w") _col = _spark;
				draw_set_colour(_pass < 4 ? _outline : _col);
				draw_rectangle(_x + _c * _u + _ox, _y + _r * _u + _oy, _x + (_c + 1) * _u - 1 + _ox, _y + (_r + 1) * _u - 1 + _oy, false);
			}
		}
	}
}

// Every player's stars, yours first and drawn bigger with a white outline.
function draw_lives_hud() {
	var _bodies = iso_bodies();
	array_sort(_bodies, function(_a, _b) { return _b.is_local - _a.is_local; });
	var _right = display_get_gui_width() - 20;
	var _y = 20;
	for (var _i = 0; _i < array_length(_bodies); _i++) {
		var _who = _bodies[_i];
		var _u = _who.is_local ? 4 : ((array_length(_bodies) > 10) ? 2 : 3);   // smaller rows with lots of players
		var _gap = _u * 3;
		var _x = _right - _who.lives_max * (9 * _u + _gap) + _gap;
		// Player number to the left of the row.
		pixel_text(_x - 3 * _u - 10, _y + 9 * _u / 2 - (_who.is_local ? 12 : 8), "P" + string(_who.player_id), _who.is_local ? 3 : 2, _who.body_col, fa_right);
		for (var _s = 0; _s < _who.lives_max; _s++) {
			var _full = _s >= _who.lives_max - _who.lives_left;   // the leftmost star goes first
			var _fill = _full ? _who.body_col : merge_colour(_who.body_col, c_black, 0.75);
			var _outline = _who.is_local ? c_white : c_black;
			draw_pixel_star(_x + _s * (9 * _u + _gap), _y, _u, _fill, _outline, _full);
		}
		if (_who.eliminated) {
			// Eliminated: a line in the player's colour struck through the whole row.
			var _x2 = _right;
			var _my = _y + 9 * _u / 2;
			draw_set_colour(c_black);
			draw_rectangle(_x - 3 * _u, _my - _u - 2, _x2 + 2 * _u, _my + _u + 1, false);
			draw_set_colour(_who.body_col);
			draw_rectangle(_x - 3 * _u + 2, _my - _u, _x2 + 2 * _u - 2, _my + _u - 1, false);
		}
		_y += 9 * _u + 14;
	}
	draw_set_colour(c_white);
}

// ---------- Kill feed: left side of the screen ----------
#macro FEED_LIFE 300            // frames an entry stays up
global.kill_feed = [];          // newest first: { killer_name, killer_col, victim_name, victim_col, out, life }

function kill_feed_add(_killer, _victim, _out) {
	var _k = instance_exists(_killer);
	array_insert(global.kill_feed, 0, {
		killer_name: _k ? _killer.body_name : "",
		killer_col: _k ? _killer.body_col : c_white,
		victim_name: _victim.body_name,
		victim_col: _victim.body_col,
		out: _out,
		life: FEED_LIFE,
	});
	if (array_length(global.kill_feed) > 5) array_resize(global.kill_feed, 5);
}

// "RED KO BLUE", "RED ELIMINATED BLUE", or "BLUE FELL" when nobody gets the credit.
function draw_kill_feed() {
	var _sc = 2, _cw = 6 * _sc;
	var _y = 100;
	for (var _i = array_length(global.kill_feed) - 1; _i >= 0; _i--) {
		global.kill_feed[_i].life -= 1;
		if (global.kill_feed[_i].life <= 0) array_delete(global.kill_feed, _i, 1);
	}
	for (var _i = 0; _i < array_length(global.kill_feed); _i++) {
		var _e = global.kill_feed[_i];
		var _parts;
		if (_e.killer_name != "") {
			_parts = [[_e.killer_name, _e.killer_col], [_e.out ? " ELIMINATED " : " KO ", c_white], [_e.victim_name, _e.victim_col]];
		} else {
			_parts = [[_e.victim_name, _e.victim_col], [_e.out ? " ELIMINATED" : " FELL", c_white]];
		}
		var _len = 0;
		for (var _p = 0; _p < array_length(_parts); _p++) _len += string_length(_parts[_p][0]);
		draw_set_colour(c_black);
		draw_set_alpha(min(0.55, _e.life / 30));
		draw_rectangle(10, _y - 4, 22 + _len * _cw, _y + 8 * _sc + 4, false);
		draw_set_alpha(min(1, _e.life / 30));
		var _x = 16;
		for (var _p = 0; _p < array_length(_parts); _p++) {
			pixel_text(_x, _y, _parts[_p][0], _sc, _parts[_p][1], fa_left);
			_x += string_length(_parts[_p][0]) * _cw;
		}
		draw_set_alpha(1);
		_y += 8 * _sc + 14;
	}
	draw_set_colour(c_white);
}

// ---------- Random islands ----------
#macro ISO_RANDOM_MAP true      // false: use the hand-made layout in oIsoWorld's Create event
global.iso_seed = 0;            // seed of the island being played
global.iso_next_seed = -1;      // a seed to replay on the next match, -1 for a new island

// Builds a random island as layout strings, in the same characters as the hand-made
// layout plus D for the dummy's start. Everything random comes from _seed, so a seed
// always gives the same island, on any PC (a LAN host only has to send the seed).
function iso_generate_layout(_seed) {
	random_set_seed(_seed);
	var _w = 26, _h = 26;
	var _cx = (_w - 1) / 2, _cy = (_h - 1) / 2;
	var _target = 290;   // land tiles before the edges get ragged, ends up about 25% more than the hand-made island

	// The outline: a circle whose radius wobbles with three random waves.
	var _wv = [random(360), random_range(0.12, 0.22), random(360), random_range(0.06, 0.14), random(360), random_range(0.04, 0.09)];
	var _inside = function(_x, _y, _cx, _cy, _r, _wv) {
		var _th = point_direction(_cx, _cy, _x, _y);
		var _rr = _r * (1 + _wv[1] * dsin(2 * _th + _wv[0]) + _wv[3] * dsin(3 * _th + _wv[2]) + _wv[5] * dsin(5 * _th + _wv[4]));
		return point_distance(_cx, _cy, _x, _y) <= _rr;
	};
	// Find the radius that gives about _target tiles.
	var _lo = 4, _hi = 13, _r = 8;
	repeat (12) {
		_r = (_lo + _hi) / 2;
		var _n = 0;
		for (var _x = 0; _x < _w; _x++) for (var _y = 0; _y < _h; _y++) if (_inside(_x, _y, _cx, _cy, _r, _wv)) _n++;
		if (_n < _target) _lo = _r; else _hi = _r;
	}
	var _land = array_create(_w);
	for (var _x = 0; _x < _w; _x++) {
		_land[_x] = array_create(_h, false);
		for (var _y = 0; _y < _h; _y++) _land[_x][_y] = _inside(_x, _y, _cx, _cy, _r, _wv);
	}

	var _dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
	var _neigh = function(_land, _x, _y, _w, _h, _dirs) {
		var _n = 0;
		for (var _d = 0; _d < 4; _d++) {
			var _u = _x + _dirs[_d][0], _v = _y + _dirs[_d][1];
			if (_u >= 0 && _v >= 0 && _u < _w && _v < _h && _land[_u][_v]) _n++;
		}
		return _n;
	};

	// Ragged edges: knock out some edge tiles, then smooth away lone bits and pinholes.
	var _edge = [];
	for (var _x = 0; _x < _w; _x++) for (var _y = 0; _y < _h; _y++) {
		if (_land[_x][_y] && _neigh(_land, _x, _y, _w, _h, _dirs) < 4) array_push(_edge, [_x, _y]);
	}
	for (var _i = 0; _i < array_length(_edge); _i++) if (random(1) < 0.3) _land[_edge[_i][0]][_edge[_i][1]] = false;
	repeat (2) {
		var _next = array_create(_w);
		for (var _x = 0; _x < _w; _x++) {
			_next[_x] = array_create(_h, false);
			for (var _y = 0; _y < _h; _y++) {
				var _n = _neigh(_land, _x, _y, _w, _h, _dirs);
				_next[_x][_y] = _land[_x][_y] ? (_n > 1) : (_n >= 3);
			}
		}
		_land = _next;
	}

	// Flood fill from (_sx, _sy) over tiles where _ok[x][y] is true. Returns the tiles reached.
	var _flood = function(_ok, _sx, _sy, _w, _h, _dirs) {
		var _seen = array_create(_w);
		for (var _x = 0; _x < _w; _x++) _seen[_x] = array_create(_h, false);
		var _out = [[_sx, _sy]];
		_seen[_sx][_sy] = true;
		for (var _q = 0; _q < array_length(_out); _q++) {
			for (var _d = 0; _d < 4; _d++) {
				var _u = _out[_q][0] + _dirs[_d][0], _v = _out[_q][1] + _dirs[_d][1];
				if (_u < 0 || _v < 0 || _u >= _w || _v >= _h || _seen[_u][_v] || !_ok[_u][_v]) continue;
				_seen[_u][_v] = true;
				array_push(_out, [_u, _v]);
			}
		}
		return _out;
	};

	// Keep only the biggest piece, so there are no floating crumbs.
	var _best = [];
	var _done = array_create(_w);
	for (var _x = 0; _x < _w; _x++) _done[_x] = array_create(_h, false);
	for (var _x = 0; _x < _w; _x++) for (var _y = 0; _y < _h; _y++) {
		if (!_land[_x][_y] || _done[_x][_y]) continue;
		var _part = _flood(_land, _x, _y, _w, _h, _dirs);
		for (var _i = 0; _i < array_length(_part); _i++) _done[_part[_i][0]][_part[_i][1]] = true;
		if (array_length(_part) > array_length(_best)) _best = _part;
	}
	for (var _x = 0; _x < _w; _x++) _land[_x] = array_create(_h, false);
	for (var _i = 0; _i < array_length(_best); _i++) _land[_best[_i][0]][_best[_i][1]] = true;

	// Starts: you a little down-left of the middle, the dummy a little up-right.
	var _nearest = function(_land, _tx, _ty, _w, _h, _ex, _ey) {
		var _bd = infinity, _bx = 0, _by = 0;
		for (var _x = 0; _x < _w; _x++) for (var _y = 0; _y < _h; _y++) {
			if (!_land[_x][_y] || (_x == _ex && _y == _ey)) continue;
			var _d = point_distance(_x, _y, _tx, _ty);
			if (_d < _bd) { _bd = _d; _bx = _x; _by = _y; }
		}
		return [_bx, _by];
	};
	var _p = _nearest(_land, _cx - 2.5, _cy + 2.5, _w, _h, -1, -1);
	var _dm = _nearest(_land, _cx + 2.5, _cy - 2.5, _w, _h, _p[0], _p[1]);
	var _dm2 = _nearest(_land, _cx - 2.5, _cy - 2.5, _w, _h, _p[0], _p[1]);   // second dummy, up-left

	var _ch = array_create(_w);
	var _free = array_create(_w);   // walkable: land with nothing on it
	for (var _x = 0; _x < _w; _x++) {
		_ch[_x] = array_create(_h, " ");
		_free[_x] = array_create(_h, false);
		for (var _y = 0; _y < _h; _y++) if (_land[_x][_y]) { _ch[_x][_y] = "."; _free[_x][_y] = true; }
	}
	_ch[_p[0]][_p[1]] = "P";
	_ch[_dm[0]][_dm[1]] = "D";
	if (_ch[_dm2[0]][_dm2[1]] == ".") _ch[_dm2[0]][_dm2[1]] = "E";
	var _walkable = array_length(_best);

	// Obstacles. Each one must sit on open land, away from both starts, not touching
	// another obstacle, and must not cut any part of the island off from the rest.
	var _feet = { B: [[0, 0]], H: [[0, 0], [1, 0]], V: [[0, 0], [0, 1]], O: [[0, 0], [1, 0], [0, 1], [1, 1]] };
	var _todo = [];
	repeat (irandom_range(5, 7)) array_push(_todo, choose("B", "B", "B", "H", "H", "V", "V", "O"));
	repeat (irandom_range(9, 13)) array_push(_todo, choose("T", "Y"));
	for (var _t = 0; _t < array_length(_todo); _t++) {
		var _letter = _todo[_t];
		var _foot = (_letter == "T" || _letter == "Y") ? _feet.B : _feet[$ _letter];
		repeat (80) {
			var _x = irandom(_w - 1), _y = irandom(_h - 1);
			var _ok = true;
			for (var _c = 0; _c < array_length(_foot) && _ok; _c++) {
				var _u = _x + _foot[_c][0], _v = _y + _foot[_c][1];
				if (_u >= _w || _v >= _h || !_free[_u][_v]) { _ok = false; break; }
				if (point_distance(_u, _v, _p[0], _p[1]) < 2.5 || point_distance(_u, _v, _dm[0], _dm[1]) < 2.5 || point_distance(_u, _v, _dm2[0], _dm2[1]) < 2.5) { _ok = false; break; }
				for (var _d = 0; _d < 4; _d++) {
					var _a = _u + _dirs[_d][0], _b = _v + _dirs[_d][1];
					if (_a >= 0 && _b >= 0 && _a < _w && _b < _h && _land[_a][_b] && !_free[_a][_b]) _ok = false;
				}
			}
			if (!_ok) continue;
			for (var _c = 0; _c < array_length(_foot); _c++) _free[_x + _foot[_c][0]][_y + _foot[_c][1]] = false;
			if (array_length(_flood(_free, _p[0], _p[1], _w, _h, _dirs)) != _walkable - array_length(_foot)) {
				for (var _c = 0; _c < array_length(_foot); _c++) _free[_x + _foot[_c][0]][_y + _foot[_c][1]] = true;
				continue;
			}
			_walkable -= array_length(_foot);
			_ch[_x][_y] = _letter;
			break;
		}
	}

	// Back to strings, one per row, skipping empty rows.
	var _rows = [];
	for (var _y = 0; _y < _h; _y++) {
		var _s = "";
		var _any = false;
		for (var _x = 0; _x < _w; _x++) { _s += _ch[_x][_y]; if (_ch[_x][_y] != " ") _any = true; }
		if (_any) array_push(_rows, _s);
	}
	randomise();   // everything after this (sparks, colours, clouds) is random again
	return _rows;
}

// ---------- Build pick: 5 seconds before each match ----------
// After PLAY the island is frozen (match_locked) and everyone picks Fire, Shadow or Time on
// their own screen: click a card, press 1 / 2 / 3, or A / D then Enter. You can change your
// mind until the timer, a thin bar under the cards, runs out. The host's timer is the one
// that counts: when it ends, anyone who hasn't picked gets a random build and the match
// begins. Joiners send their pick to the host ("pick") and see everyone's in its snapshots.
global.build_cards = [
	{ name: "FIRE", col: make_colour_rgb(252, 140, 40), cd: "SPACE - 12S COOLDOWN",
	  lines: ["SPACE LIGHTS YOUR", "CHAIN FOR 8 SECONDS.", "IT HEATS AS YOU WHIP,", "HITS HARDER AND SETS", "TILES ON FIRE."] },
	{ name: "SHADOW", col: make_colour_rgb(176, 120, 255), cd: "SPACE - 6S COOLDOWN",
	  lines: ["BECOME A SHADOW FOR", "2 SECONDS. CHAINS", "PASS RIGHT THROUGH", "YOU AND YOU MOVE", "A LITTLE FASTER."] },
	{ name: "TIME", col: make_colour_rgb(240, 204, 104), cd: "SPACE - 8S COOLDOWN",
	  lines: ["JUMP BACK TO WHERE", "YOU STOOD 0.8", "SECONDS AGO. WORKS", "WHILE FALLING, SO IT", "CAN SAVE YOUR LIFE."] },
];
global.pick_choice = -1;   // the build you picked, -1 if none yet
global.pick_hover = -1;    // the card under the mouse, or picked out with A / D
global.pick_lock = 0;      // frames to ignore keys, so the press on PLAY doesn't pick

function match_picking() {
	return global.match_countdown > MATCH_GO_FRAMES;
}

function build_pick_reset() {
	global.pick_choice = -1;
	global.pick_hover = -1;
	global.pick_lock = 10;
}

// Pick build _b for yourself.
function build_pick(_b) {
	if (!match_picking()) return;
	global.pick_choice = _b;
	global.build = _b;
	if (global.net_client_match) {
		net_client_send({ t: "pick", b: _b });
		return;
	}
	with (oIsoPlayer) if (is_local) {
		build = _b;
		build_picked = true;
	}
}

// Host: the timer ran out. Anyone who didn't pick gets a random build.
function build_pick_finish() {
	with (oIsoPlayer) {
		if (!build_picked) build = irandom(2);
		build_picked = true;
		if (is_local) {
			global.build = build;
			global.pick_choice = build;
		}
	}
}

// Card _i on the GUI layer: [x1, y1, x2, y2].
function pick_card_rect(_i) {
	var _w = 280, _h = 340, _gap = 36;
	var _x = (display_get_gui_width() - (3 * _w + 2 * _gap)) / 2 + _i * (_w + _gap);
	var _y = display_get_gui_height() / 2 - 210;
	return [_x, _y, _x + _w, _y + _h];
}

// Every frame (oIsoWorld Step): your pick while the screen is up.
function build_pick_step() {
	if (!match_picking() || global.pause_open || global.menu_open) return;
	if (global.pick_lock > 0) {
		global.pick_lock--;
		return;
	}
	var _mx = device_mouse_x_to_gui(0);
	var _my = device_mouse_y_to_gui(0);
	var _over = -1;
	for (var _i = 0; _i < 3; _i++) {
		var _r = pick_card_rect(_i);
		if (point_in_rectangle(_mx, _my, _r[0], _r[1], _r[2], _r[3])) _over = _i;
	}
	if (_over != -1 && _over != global.pick_hover) {
		global.pick_hover = _over;
		audio_ui_hover();
	}
	var _dir = (keyboard_check_pressed(ord("D")) || keyboard_check_pressed(vk_right)) - (keyboard_check_pressed(ord("A")) || keyboard_check_pressed(vk_left));
	if (_dir != 0) {
		global.pick_hover = (max(0, global.pick_hover) + (global.pick_hover < 0 ? 0 : _dir) + 3) mod 3;
		audio_ui_hover();
	}
	var _b = -1;
	if (mouse_check_button_pressed(mb_left) && _over != -1) _b = _over;
	if ((keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space)) && global.pick_hover >= 0) _b = global.pick_hover;
	for (var _k = 0; _k < 3; _k++) if (keyboard_check_pressed(ord(string(_k + 1)))) _b = _k;
	if (_b >= 0) {
		audio_ui_click();
		build_pick(_b);
	}
}

function draw_build_pick() {
	var _gw = display_get_gui_width();
	var _gh = display_get_gui_height();
	draw_set_alpha(0.6);
	draw_set_colour(make_colour_rgb(12, 18, 40));
	draw_rectangle(0, 0, _gw, _gh, false);
	draw_set_alpha(1);
	var _first = pick_card_rect(0);
	var _last = pick_card_rect(2);
	pixel_text(_gw / 2, _first[1] - 72, "CHOOSE YOUR POWER", 5, c_white, fa_center);
	for (var _i = 0; _i < 3; _i++) {
		var _r = pick_card_rect(_i);
		var _c = global.build_cards[_i];
		var _picked = global.pick_choice == _i;
		var _hot = global.pick_hover == _i;
		draw_set_colour(c_black);
		draw_rectangle(_r[0] - 4, _r[1] - 4, _r[2] + 4, _r[3] + 4, false);
		draw_set_colour(_picked ? c_white : (_hot ? _c.col : make_colour_rgb(70, 76, 100)));
		draw_rectangle(_r[0], _r[1], _r[2], _r[3], false);
		draw_set_colour(_picked ? make_colour_rgb(44, 52, 92) : make_colour_rgb(26, 30, 52));
		draw_rectangle(_r[0] + 6, _r[1] + 6, _r[2] - 6, _r[3] - 6, false);
		var _cx = (_r[0] + _r[2]) / 2;
		draw_sprite_ext(sAbilityIcon, _i, _cx, _r[1] + 60, 4, 4, 0, c_white, 1);
		pixel_text(_cx, _r[1] + 104, _c.name, 4, _c.col, fa_center);
		pixel_text(_cx, _r[1] + 146, _c.cd, 2, make_colour_rgb(130, 136, 160), fa_center);
		for (var _k = 0; _k < array_length(_c.lines); _k++) {
			pixel_text(_cx, _r[1] + 180 + _k * 22, _c.lines[_k], 2, make_colour_rgb(210, 216, 235), fa_center);
		}
		pixel_text(_cx, _r[3] - 34, _picked ? "PICKED" : string(_i + 1), 2, _picked ? c_white : make_colour_rgb(130, 136, 160), fa_center);
	}
	// The timer: a thin bar under the cards that drains smoothly to nothing.
	var _left = clamp((global.match_countdown - MATCH_GO_FRAMES) / MATCH_PICK_FRAMES, 0, 1);
	var _by = _first[3] + 30;
	draw_set_colour(c_black);
	draw_rectangle(_first[0] - 2, _by - 2, _last[2] + 2, _by + 6, false);
	draw_set_colour(make_colour_rgb(50, 54, 70));
	draw_rectangle(_first[0], _by, _last[2], _by + 4, false);
	draw_set_colour((global.pick_choice >= 0) ? global.build_cards[global.pick_choice].col : c_white);
	if (_left > 0) draw_rectangle(_first[0], _by, _first[0] + (_last[2] - _first[0]) * _left, _by + 4, false);
	var _hint = (global.pick_choice >= 0) ? "YOU CAN STILL CHANGE IT" : "CLICK A CARD, OR PRESS 1 / 2 / 3.  NO PICK = RANDOM";
	pixel_text(_gw / 2, _by + 24, _hint, 2, make_colour_rgb(170, 190, 220), fa_center);
	draw_set_colour(c_white);
}

// ---------- Match flow: who's left, the win screen, and back to the lobby ----------
// One place for the rules of a match, so co-op can build on it.
#macro MATCH_END_FRAMES 180    // 3 second countdown before going back to the lobby
#macro MATCH_PICK_FRAMES 300  // 5 seconds to pick a build before a match (see Build pick)
#macro MATCH_GO_FRAMES 45      // how long GO stays up (you can already move)
global.match_countdown = 0;    // frames left of the build pick and GO
global.match_frame = 0;        // frames since the match began, stamped on every event
global.match_players = 0;      // bodies in the match when it started (set when the build is picked)
global.match_over = false;
global.match_winner = noone;   // the last one standing, or noone if nobody was
global.match_timer = 0;        // frames left on the countdown
global.return_to_lobby = false;   // the menu opens on the host lobby after the restart

function match_reset() {
	global.match_players = 0;
	global.match_frame = 0;
	global.match_countdown = 0;
	global.event_log = [];
	global.match_over = false;
	global.match_winner = noone;
	global.match_timer = 0;
	drops_reset();
}

// Call when the match begins.
function match_start() {
	match_reset();
	global.match_players = array_length(iso_bodies());
	global.match_countdown = MATCH_PICK_FRAMES + MATCH_GO_FRAMES;
	build_pick_reset();
	game_event("match_start", { players: global.match_players, seed: global.iso_seed });
}

// True until GO (the build pick): nobody can move, whip or use abilities.
function match_locked() {
	return global.match_countdown > MATCH_GO_FRAMES;
}

// The build pick screen, then GO in the middle of the screen at a fixed size, so it stays crisp.
function draw_match_countdown() {
	if (global.match_countdown <= 0) return;
	if (match_picking()) {
		draw_build_pick();
		return;
	}
	var _gw = display_get_gui_width();
	var _gh = display_get_gui_height();
	var _text = "GO";
	var _phase = (MATCH_GO_FRAMES - global.match_countdown) / MATCH_GO_FRAMES;
	var _sc = 5;
	var _col = make_colour_rgb(255, 205, 50);
	draw_set_alpha(1 - _phase);
	var _y = _gh / 2 - 120;
	pixel_text(_gw / 2 + 2, _y + 2, _text, _sc, c_black, fa_center);
	pixel_text(_gw / 2, _y, _text, _sc, _col, fa_center);
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

// Every unpaused frame. A match that started with 2 or more players ends when one is
// left; on your own (testing with F1 dummies) it never ends by itself.
function match_step() {
	global.match_frame++;
	// The build pick, then GO (control unlocks on GO). Anyone who hasn't picked by then gets a random build.
	if (global.match_countdown > 0) {
		global.match_countdown--;
		if (global.match_countdown == MATCH_GO_FRAMES) {
			build_pick_finish();
			game_event("go");
		}
	}
	drops_host_step();   // sky drops (see Sky drops)
	if (!global.match_over) {
		if (global.match_players < 2) return;
		var _alive = [];
		var _all = iso_bodies();
		for (var _i = 0; _i < array_length(_all); _i++) if (!_all[_i].eliminated) array_push(_alive, _all[_i]);
		if (array_length(_alive) > 1) return;
		global.match_over = true;
		global.match_winner = (array_length(_alive) == 1) ? _alive[0] : noone;
		global.match_timer = MATCH_END_FRAMES;
		game_event("match_won", { winner: instance_exists(global.match_winner) ? global.match_winner.player_id : -1 });
		return;
	}
	global.match_timer--;
	if (global.match_timer <= 0) {
		global.return_to_lobby = true;
		room_restart();
	}
}

// The win screen, drawn on the local player's GUI.
function draw_match_end() {
	var _gw = display_get_gui_width();
	var _gh = display_get_gui_height();
	var _w = global.match_winner;
	var _me = instance_exists(_w) && _w.is_local;
	var _text = "DRAW", _col = c_white;
	if (_me) { _text = "YOU WON"; _col = make_colour_rgb(255, 205, 50); }
	else if (instance_exists(_w)) { _text = "P" + string(_w.player_id) + " WON"; _col = _w.body_col; }
	// Bold: the same text drawn a few times a pixel apart, over a thick dark shadow.
	var _sc = 9, _y = _gh / 2 - 140;
	for (var _o = 0; _o < 3; _o++) pixel_text(_gw / 2 + _o * 2, _y + 6, _text, _sc, c_black, fa_center);
	for (var _o = 0; _o < 3; _o++) pixel_text(_gw / 2 + _o, _y, _text, _sc, _col, fa_center);
	var _secs = max(1, ceil(global.match_timer / 60));
	pixel_text(_gw / 2, _y + 120, "RETURNING TO LOBBY IN " + string(_secs), 3, c_white, fa_center);
	draw_set_colour(c_white);
}

// ---------- Event log ----------
// Every gameplay event goes through game_event: it's stamped with the frame, kept in
// global.event_log, and only then applied. Online, the host will send this same stream
// to everyone. Bodies are named by player number, props and tiles by their tile.
//   hit          victim, by, x, y, from_x, from_y, force
//   prop_hit     gx, gy, dmg, side, by
//   prop_broken  gx, gy
//   tile_ignite  gx, gy, by
//   tile_crumble gx, gy
//   life_lost    victim, by, x, y
//   eliminated   victim, by
//   ability      player, build, x, y
//   match_start  players, seed
//   go
//   match_won    winner (-1 if nobody)
//   drop_spawn   n, kind, gx, gy   (see Sky drops)
//   drop_land    n
//   drop_grab    n, player, kind
//   drop_gone    n
#macro EVENT_LOG_MAX 512       // oldest events drop off after this many
global.event_log = [];

function game_event(_type, _data = undefined) {
	if (is_undefined(_data)) _data = {};
	_data.type = _type;
	_data.frame = global.match_frame;
	// A joiner's game only shows what the host sends, so it makes no events of its own.
	if (global.net_client_match) return _data;
	array_push(global.event_log, _data);
	if (array_length(global.event_log) > EVENT_LOG_MAX) array_delete(global.event_log, 0, 1);
	// Hosting a LAN match: everyone gets it with the next snapshot (before it's applied, so
	// anything it sets off, like "eliminated", goes after it).
	if (global.net_role == "host" && global.net_in_match && array_length(global.net_match_socks) > 0) array_push(global.net_out_events, _data);
	event_apply(_data);
	return _data;
}

// The body with player number _pid, or noone.
function iso_body_by_pid(_pid) {
	if (_pid < 0) return noone;
	var _all = iso_bodies();
	for (var _i = 0; _i < array_length(_all); _i++) if (_all[_i].player_id == _pid) return _all[_i];
	return noone;
}

// What each event does to the game. Events that only record something have no case.
function event_apply(_e) {
	switch (_e.type) {
		case "hit": {
			var _victim = iso_body_by_pid(_e.victim);
			var _hitter = iso_body_by_pid(_e.by);
			if (instance_exists(_victim)) with (_victim) body_knock_apply(_e.from_x, _e.from_y, _e.force, _hitter);
			sfx_clash();
			break;
		}
		case "prop_hit": {
			if (!iso_in_bounds(_e.gx, _e.gy)) break;
			var _prop = global.iso_prop[_e.gx][_e.gy];
			if (!instance_exists(_prop) || _prop.broken || _prop.falling) break;
			var _boulder = _prop.is_boulder;
			_prop.take_hit(_e.dmg, _e.side);
			// The hit that breaks it only plays the break; otherwise stone on boulders, a knock on trees.
			if (_prop.broken) sfx_play(snd_break, 0, 0.07);
			else if (_boulder) sfx_play(snd_rock_hit, -6.2, 0.08);
			else sfx_play(snd_prop_hit, -9.7, 0.08);
			break;
		}
		case "ability": {
			var _who = iso_body_by_pid(_e.player);
			// The activation sound is only for the player who used it, not everyone else.
			if (instance_exists(_who) && _who.is_local) {
				switch (_e.build) {
					case BUILD.FIRE:   sfx_play(snd_fire, -8.5, 0.04); break;   // 6 dB under the doc's -2.5, as asked
					case BUILD.SHADOW: sfx_play(snd_shadow, -1.5, 0.04); break;
					case BUILD.TIME:   sfx_play(snd_time, -6.8, 0.03); break;
				}
			}
			if (instance_exists(_who)) {
				_who.ab_fx_t = 0;
				_who.ab_fx_build = _e.build;
				// Time: only the player who used it hears the warp.
				if (_e.build == BUILD.TIME && _who.is_local) audio_time_warp();
			}
			break;
		}
		case "drop_spawn":
			array_push(global.drops, { n: _e.n, kind: _e.kind, gx: _e.gx, gy: _e.gy, t: 0, landed: false, age: 0 });
			break;
		case "drop_land": {
			var _i = drop_find(_e.n);
			if (_i < 0) break;
			var _d = global.drops[_i];
			var _sx = iso_to_screen_x(_d.gx, _d.gy), _sy = iso_to_screen_y(_d.gx, _d.gy);
			if (_d.kind == DROP.FIREBALL) {
				// Impact: a burst of embers, a shockwave and a shake. It's gone; the fire stays.
				array_delete(global.drops, _i, 1);
				drop_burst(_sx, _sy - 6, 34, DROP.FIREBALL, 4.5);
				array_push(global.drop_rings, { px: _sx, py: _sy, t: 0 });
				global.shake = max(global.shake, 5);
				// A stone thud, and the start of the Fire whoosh faded out quickly. snd_fire is a
				// 9 second burn, so left alone it piles up when fireballs come every few seconds.
				sfx_play(snd_rock_hit, -8, 0.06, 0.6);
				var _v = sfx_play(snd_fire, -10, 0.05, 0.7);
				audio_sound_gain(_v, 0, 600);
				array_push(global.drop_sounds, { v: _v, t: 40 });
			} else {
				_d.landed = true;
				_d.age = 0;
				drop_burst(_sx, _sy - 8, 12, _d.kind, 2);
			}
			break;
		}
		case "drop_grab": {
			var _i = drop_find(_e.n);
			if (_i >= 0) {
				var _d = global.drops[_i];
				drop_burst(iso_to_screen_x(_d.gx, _d.gy), iso_to_screen_y(_d.gx, _d.gy) - 14, 18, _d.kind, 2.5);
				array_delete(global.drops, _i, 1);
			}
			var _who = iso_body_by_pid(_e.player);
			if (instance_exists(_who) && _who.object_index == oIsoPlayer) {
				_who.pu_kind = _e.kind;
				_who.pu_left = (_e.kind == DROP.SPEED) ? PU_SPEED_FRAMES : PU_TRIPLE_SWINGS;
				if (_who.is_local) sfx_play(snd_time, -12, 0.03, 1.4);   // only the one who took it hears it
			}
			break;
		}
		case "drop_gone": {
			var _i = drop_find(_e.n);
			if (_i < 0) break;
			var _d = global.drops[_i];
			drop_burst(iso_to_screen_x(_d.gx, _d.gy), iso_to_screen_y(_d.gx, _d.gy) - 14, 8, _d.kind, 1.5);
			array_delete(global.drops, _i, 1);
			break;
		}
		case "tile_ignite":
			if (iso_has_floor(_e.gx, _e.gy)) global.iso_burn[_e.gx][_e.gy] = ISO_BURN_FRAMES;
			break;
		case "tile_crumble":
			iso_crumble_tile_apply(_e.gx, _e.gy);
			break;
		case "life_lost": {
			var _who = iso_body_by_pid(_e.victim);
			if (!instance_exists(_who)) break;
			with (_who) {
				lives_left = max(0, lives_left - 1);
				lives_pop = 40;
				if (lives_left == 0) eliminated = true;
				last_hit_by = noone;
				last_hit_timer = 0;
				if (variable_instance_exists(id, "pu_kind")) { pu_kind = -1; pu_left = 0; }   // a power-up goes with the life
			}
			kill_feed_add(iso_body_by_pid(_e.by), _who, _who.eliminated);
			// The killer shimmers with their build's sparks for a few seconds.
			var _killer = iso_body_by_pid(_e.by);
			if (instance_exists(_killer) && _killer.object_index == oIsoPlayer) _killer.kill_fx_left = irandom_range(180, 300);
			if (_who.eliminated) game_event("eliminated", { victim: _e.victim, by: _e.by });
			break;
		}
	}
}

// ---------- Prop shadows ----------
// Trees and boulders lay a soft shadow on the grass, as if lit from the top left: the
// sprite is flattened onto the ground, leaning down and to the right. The shShadow shader
// blurs its edges; if it can't compile, a plain flat silhouette is drawn instead.
#macro SHADOW_KX 0.7       // how far right the shadow leans, per pixel of height
#macro SHADOW_KY 0.28      // and how far down
#macro SHADOW_ALPHA 0.32
global.u_shadow_texel = -1;

// Call from a tree or boulder's Draw, before drawing the sprite.
function draw_prop_shadow() {
	if (falling) return;
	var _a = SHADOW_ALPHA * max(0, image_alpha);
	if (_a <= 0) return;
	var _spr = sprite_index, _sub = image_index;
	var _w = sprite_get_width(_spr), _h = sprite_get_height(_spr);
	var _xo = sprite_get_xoffset(_spr), _yo = sprite_get_yoffset(_spr);
	// Shorter at the edge of the island, so it doesn't hang out over the sky.
	var _len = iso_has_floor(gx + 1, gy) ? 1 : 0.45;
	var _kx = SHADOW_KX * _len, _ky = SHADOW_KY * _len;
	var _l = x - _xo, _r = x - _xo + _w;
	var _tx = _yo * _kx, _ty = _yo * _ky;                  // where the top of the sprite lands
	var _bx = -(_h - _yo) * _kx, _by = -(_h - _yo) * _ky;  // and the bottom
	var _soft = shader_is_compiled(shShadow);
	if (_soft) {
		if (global.u_shadow_texel == -1) global.u_shadow_texel = shader_get_uniform(shShadow, "u_texel");
		var _tex = sprite_get_texture(_spr, _sub);
		shader_set(shShadow);
		shader_set_uniform_f(global.u_shadow_texel, texture_get_texel_width(_tex), texture_get_texel_height(_tex));
	} else {
		gpu_set_fog(true, make_colour_rgb(12, 20, 30), 0, 0);   // fog with no range paints it one flat colour
	}
	draw_sprite_pos(_spr, _sub, _l + _tx, y + _ty, _r + _tx, y + _ty, _r + _bx, y + _by, _l + _bx, y + _by, _a);
	if (_soft) shader_reset(); else gpu_set_fog(false, c_black, 0, 0);
}

// ---------- Input ----------
// Every player is driven by an input record, filled once per frame in Begin Step and read
// in Step. Your player fills it from the keyboard and mouse; dummies leave it empty for now;
// online, a remote player's record will be filled from the network instead.
//   move_x, move_y  -1, 0 or 1 on screen (D / A, S / W)
//   aim_gx, aim_gy  grid position the whip is aimed at
//   whip            whip pressed this frame
//   ability         ability pressed this frame
//   pause           pause pressed this frame
function input_new() {
	return { move_x: 0, move_y: 0, aim_gx: 0, aim_gy: 0, whip: false, ability: false, pause: false };
}

function input_clear(_in) {
	_in.move_x = 0;
	_in.move_y = 0;
	_in.whip = false;
	_in.ability = false;
	_in.pause = false;
}

function input_read_local(_in) {
	_in.move_x = (keyboard_check(ord("D")) || keyboard_check(vk_right)) - (keyboard_check(ord("A")) || keyboard_check(vk_left));
	_in.move_y = (keyboard_check(ord("S")) || keyboard_check(vk_down)) - (keyboard_check(ord("W")) || keyboard_check(vk_up));
	_in.aim_gx = screen_to_iso_x(mouse_x, mouse_y);
	_in.aim_gy = screen_to_iso_y(mouse_x, mouse_y);
	_in.whip = mouse_check_button_pressed(mb_left);
	_in.ability = keyboard_check_pressed(vk_space);
	_in.pause = keyboard_check_pressed(vk_escape);
	// A menu is up: the game runs on, but your player gets no controls.
	if (global.menu_open || global.pause_open) {
		_in.move_x = 0;
		_in.move_y = 0;
		_in.whip = false;
		_in.ability = false;
	}
}

// The player at this keyboard, or noone.
function iso_local_player() {
	var _me = noone;
	with (oIsoPlayer) if (is_local) _me = id;
	return _me;
}

// ---------- LAN ----------
// The host opens a TCP server and broadcasts "a game is hosted here" over UDP once a
// second. Joiners listen for those broadcasts, list the games, and connect over TCP.
// The host owns the lobby: it sends every joiner a copy whenever anything changes (and
// once a second as a keep-alive). Joiners only ever ask for their own build to change.
// Messages are small JSON structs with a type in t. oNet handles the network events.
//   host -> joiner:  lobby { you, slots, builds, kinds, in_match }, full, closed,
//                    start { seed, you, build }, snap { m, b, ev } (see Match over LAN)
//   joiner -> host:  build { dir }, pick { b }, in { mx, my, ax, ay, w, a }
//   broadcast:       nascon { players, max, in_match }
#macro NET_PORT 6510          // TCP: the lobby connection
#macro NET_FIND_PORT 6511     // UDP: broadcasts go to this port and the next few, so a few
#macro NET_FIND_PORTS 4       //      copies of the game on one PC can all listen at once
global.net_role = "none";     // "host", "client" (joined someone) or "none"
global.net_mode = "lan";      // how: "lan" (sockets) or "steam" (online, see Steam below)
global.net_my_slot = -1;      // client: your slot in the host's lobby
global.net_status = "";       // shown on the join screen
global.net_in_match = false;  // the host is playing a match (joiners wait in the lobby)
#macro NET_SNAP_EVERY 2       // the host sends a snapshot every this many frames (30 a second)
global.net_client_match = false;  // joined: playing the host's match (this game only draws what it sends)
global.net_client_ready = false;  // joined: the match's island is built and snapshots can go on it
global.net_my_pid = -1;           // joined: your player number in the match
global.net_match_socks = [];      // host: the joiners playing this match
global.net_out_events = [];       // host: events made since the last snapshot
global.net_snap = undefined;      // joined: the newest snapshot, not yet applied
global.net_event_queue = [];      // joined: the host's events, not yet applied
global.net_after_drop = false;
global.net_last_shake = 0;        // joined: the host's shake in the last snapshot    // joined: lost the host mid-match, so the menu opens on the game list

function net_ensure() {
	if (!instance_exists(oNet)) instance_create_depth(0, 0, 0, oNet);
	return instance_find(oNet, 0);
}

function net_write(_struct) {
	var _s = json_stringify(_struct);
	var _b = buffer_create(string_byte_length(_s) + 1, buffer_fixed, 1);
	buffer_write(_b, buffer_string, _s);
	return _b;
}

// _sock is a peer: a socket on LAN, a Steam ID online (see Steam below).
function net_send(_sock, _struct) {
	var _b = net_write(_struct);
	net_send_buffer(_sock, _b);
	buffer_delete(_b);
}

function net_send_buffer(_sock, _b) {
	if (global.net_mode == "steam") {
		if (_sock <= 0 || !net_steam_ok()) return;
		steam_net_packet_send(_sock, _b, buffer_get_size(_b), steam_net_packet_type_reliable);
	} else if (_sock >= 0) {
		network_send_packet(_sock, _b, buffer_get_size(_b));
	}
}

// Let go of a joiner. Online there's nothing to close: they leave the Steam lobby themselves.
function net_close_peer(_sock) {
	if (global.net_mode != "steam" && _sock >= 0) network_destroy(_sock);
}

function net_read(_buf) {
	try {
		buffer_seek(_buf, buffer_seek_start, 0);
		return json_parse(buffer_read(_buf, buffer_string));
	} catch (_e) {
		return undefined;
	}
}

// ----- Hosting -----
function net_host_open() {
	var _n = net_ensure();
	if (_n.role == "host") return global.net_mode == "lan";
	if (_n.role == "client") net_drop("");
	global.net_mode = "lan";
	_n.server = network_create_server(network_socket_tcp, NET_PORT, LOBBY_MAX);
	if (_n.server < 0) {
		global.net_status = "COULDN'T OPEN PORT " + string(NET_PORT);
		return false;
	}
	_n.udp_send = network_create_socket(network_socket_udp);
	_n.role = "host";
	global.net_role = "host";
	global.net_status = "";
	net_broadcast_presence();
	return true;
}

// Stop hosting: tell everyone, empty their slots, close the sockets.
function net_host_close() {
	if (!instance_exists(oNet) || oNet.role != "host") return;
	for (var _i = array_length(global.lobby_slots) - 1; _i >= 1; _i--) {
		if (global.lobby_kind[_i] != "player") continue;
		var _s = global.lobby_sock[_i];
		net_send(_s, { t: "closed" });
		net_close_peer(_s);
		lobby_remove_at(_i);
	}
	with (oNet) {
		if (server >= 0) network_destroy(server);
		if (udp_send >= 0) network_destroy(udp_send);
		if (global.net_mode == "steam" && net_steam_ok()) steam_lobby_leave();
		server = -1;
		udp_send = -1;
		steam_lobby = 0;
		steam_missing = {};
		role = "none";
	}
	if (array_length(global.lobby_names) > 0) global.lobby_names[0] = "";
	global.net_role = "none";
	global.net_in_match = false;
	global.net_match_socks = [];
	global.net_out_events = [];
}

function net_is_open() {
	return global.net_role == "host";
}

function net_lan_open() {
	return global.net_role == "host" && global.net_mode == "lan";
}

function net_online_open() {
	return global.net_role == "host" && global.net_mode == "steam";
}

function net_broadcast_presence() {
	if (global.net_mode == "steam") {   // online: update what Steam's game list shows instead
		net_steam_tag_lobby();
		return;
	}
	if (!instance_exists(oNet) || oNet.udp_send < 0) return;
	var _b = net_write({ t: "nascon", players: array_length(global.lobby_slots), max: LOBBY_MAX, in_match: global.net_in_match });
	for (var _p = 0; _p < NET_FIND_PORTS; _p++) network_send_broadcast(oNet.udp_send, NET_FIND_PORT + _p, _b, buffer_get_size(_b));
	buffer_delete(_b);
}

// Every joiner gets the whole lobby, plus which slot is theirs.
function net_send_lobby() {
	if (global.net_role != "host") return;
	for (var _i = 1; _i < array_length(global.lobby_slots); _i++) {
		if (global.lobby_kind[_i] != "player") continue;
		net_send(global.lobby_sock[_i], {
			t: "lobby", you: _i, in_match: global.net_in_match,
			slots: global.lobby_slots, builds: global.lobby_builds, kinds: global.lobby_kind,
			names: global.lobby_names,
		});
	}
}

function net_lobby_changed() {
	if (global.net_role == "host") net_send_lobby();
}

function net_slot_of(_sock) {
	for (var _i = 1; _i < array_length(global.lobby_sock); _i++) if (global.lobby_sock[_i] == _sock) return _i;
	return -1;
}

// Someone connected (LAN) or said hello (online): they take the next free slot, or are
// turned away if it's full.
function net_host_on_connect(_sock) {
	var _name = (global.net_mode == "steam") ? net_clean_name(steam_get_user_persona_name_sync(_sock), 12) : "";
	if (lobby_add("player", _sock, _name) < 0) {
		net_send(_sock, { t: "full" });
		net_close_peer(_sock);
	}
}

function net_host_on_disconnect(_sock) {
	// Mid-match their player just stands still (proper leaving comes later).
	with (oIsoPlayer) if (net_sock == _sock) {
		net_sock = -1;
		input_clear(net_in);
	}
	var _k = array_get_index(global.net_match_socks, _sock);
	if (_k >= 0) array_delete(global.net_match_socks, _k, 1);
	lobby_remove_at(net_slot_of(_sock));
}

function net_host_on_data(_sock, _msg) {
	var _slot = net_slot_of(_sock);
	if (_slot < 0 || !variable_struct_exists(_msg, "t")) return;
	switch (_msg.t) {
		case "build":
			if (variable_struct_exists(_msg, "dir")) lobby_cycle_build(_slot, sign(_msg.dir));
			break;
		case "pick":
			// Their build on the pick screen, while it's up.
			if (!variable_struct_exists(_msg, "b") || !match_picking()) break;
			with (oIsoPlayer) if (net_sock == _sock) {
				build = clamp(floor(_msg.b), 0, 2);
				build_picked = true;
			}
			break;
		case "in":
			// Their controls. Whip and ability presses stick until their player reads them,
			// so a press isn't lost when two messages land in one frame.
			if (!variable_struct_exists(_msg, "mx")) break;
			with (oIsoPlayer) if (net_sock == _sock) {
				net_in.move_x = sign(_msg.mx);
				net_in.move_y = sign(_msg.my);
				net_in.aim_gx = _msg.ax;
				net_in.aim_gy = _msg.ay;
				if (_msg.w) net_in.whip = true;
				if (_msg.a) net_in.ability = true;
			}
			break;
	}
}

// ----- Joining -----
// Start listening for games on the network (the join screen).
function net_join_open(_keep_status = false) {
	var _n = net_ensure();
	if (_n.role == "host") net_host_close();
	global.net_mode = "lan";
	_n.games = [];
	with (_n) net_check_local_host();
	for (var _p = 0; _p < NET_FIND_PORTS && _n.udp_listen < 0; _p++) {
		_n.udp_listen = network_create_server(network_socket_udp, NET_FIND_PORT + _p, 1);
	}
	if (_keep_status && global.net_status != "") return;
	global.net_status = (_n.udp_listen < 0) ? "CAN'T LISTEN FOR GAMES ON THIS PC" : "LOOKING FOR GAMES ON YOUR NETWORK...";
}

// Run as oNet. Is another copy of the game on this PC hosting? Its lobby port is taken if so:
// try to open it for a moment, and close it straight away if that works.
function net_check_local_host() {
	var _s = network_create_server(network_socket_tcp, NET_PORT, 1);
	local_host = _s < 0;
	if (_s >= 0) network_destroy(_s);
}

function net_join_close() {
	if (!instance_exists(oNet)) return;
	with (oNet) {
		if (udp_listen >= 0) network_destroy(udp_listen);
		udp_listen = -1;
		games = [];
		steam_games = [];
		browsing = false;
		listing = false;
	}
}

// A "game hosted here" broadcast.
function net_on_presence(_msg, _ip) {
	if (!variable_struct_exists(_msg, "t") || _msg.t != "nascon") return;
	with (oNet) {
		var _g = undefined;
		for (var _i = 0; _i < array_length(games); _i++) if (games[_i].ip == _ip) _g = games[_i];
		if (is_undefined(_g)) {
			_g = { ip: _ip, players: 0, max: LOBBY_MAX, in_match: false, seen: 0 };
			array_push(games, _g);
		}
		_g.players = _msg.players;
		_g.max = _msg.max;
		_g.in_match = _msg.in_match;
		_g.seen = current_time;
	}
}

function net_join_connect(_ip) {
	var _n = net_ensure();
	if (_n.sock >= 0) return;
	global.net_mode = "lan";
	_n.sock = network_create_socket(network_socket_tcp);
	_n.role = "client";
	_n.connecting = true;
	_n.last_heard = current_time;
	global.net_role = "client";
	global.net_my_slot = -1;
	global.net_status = "CONNECTING TO " + _ip + "...";
	if (_n.sock < 0 || network_connect_async(_n.sock, _ip, NET_PORT) < 0) net_drop("COULDN'T CONNECT");
}

function net_client_send(_struct) {
	if (instance_exists(oNet) && oNet.role == "client" && !oNet.connecting) net_send(oNet.sock, _struct);
}

// Leave the host (or give up connecting). _reason is shown on the join screen.
function net_drop(_reason) {
	if (instance_exists(oNet)) {
		with (oNet) {
			if (role == "client" && global.net_mode == "steam") {
				if (net_steam_ok()) steam_lobby_leave();
				steam_lobby = 0;
			} else if (global.net_mode != "steam" && sock >= 0) {
				network_destroy(sock);
			}
			sock = -1;
			connecting = false;
			if (role == "client") role = "none";
		}
	}
	if (global.net_role == "client") {
		global.net_role = "none";
		// The lobby was the host's copy. Start your own fresh if you host later.
		global.lobby_slots = [];
		global.lobby_builds = [];
		global.lobby_kind = [];
		global.lobby_sock = [];
		global.lobby_names = [];
	}
	global.net_my_slot = -1;
	global.net_in_match = false;
	global.net_status = _reason;
	// In the host's match: back to the menus (the game list, showing why, if there's a reason).
	if (global.net_client_match) {
		global.net_client_match = false;
		global.net_client_ready = false;
		global.net_after_drop = _reason != "";
		room_restart();
	}
}

function net_client_on_data(_msg) {
	if (!variable_struct_exists(_msg, "t")) return;
	switch (_msg.t) {
		case "lobby":
			global.lobby_slots = _msg.slots;
			global.lobby_builds = _msg.builds;
			global.lobby_kind = _msg.kinds;
			global.lobby_sock = array_create(array_length(_msg.slots), -1);
			global.lobby_names = variable_struct_exists(_msg, "names") ? _msg.names : array_create(array_length(_msg.slots), "");
			global.net_my_slot = _msg.you;
			global.net_in_match = _msg.in_match;
			global.net_status = "";
			// The host's match ended: back to its lobby with everyone.
			if (global.net_client_match && !_msg.in_match) {
				global.net_client_match = false;
				global.net_client_ready = false;
				global.return_to_lobby = true;
				room_restart();
			}
			break;
		case "start":
			// The host pressed PLAY: build the same island from its seed (oIsoWorld then
			// skips its own player and menu, see net_client_match) and wait for snapshots.
			global.net_client_match = true;
			global.net_client_ready = false;
			global.net_my_pid = _msg.you;
			global.build = _msg.build;
			global.iso_next_seed = _msg.seed;
			global.net_snap = undefined;
			global.net_event_queue = [];
			global.pause_open = false;
			global.match_countdown = MATCH_PICK_FRAMES + MATCH_GO_FRAMES;   // the pick screen, until the host's snapshots take over
			build_pick_reset();
			room_restart();
			break;
		case "snap":
			if (!global.net_client_match) break;
			global.net_snap = _msg;
			for (var _i = 0; _i < array_length(_msg.ev); _i++) array_push(global.net_event_queue, _msg.ev[_i]);
			break;
		case "full":
			net_drop("THAT GAME IS FULL");
			break;
		case "closed":
			net_drop("THE HOST CLOSED THE GAME");
			break;
	}
}

// ---------- Steam (online) ----------
// The same lobby and match messages as LAN, carried by Steam instead of sockets
// (global.net_mode says which). A peer (lobby_sock, oNet.sock, a player's net_sock,
// net_match_socks) is a socket on LAN and a Steam ID online. The host makes a public Steam
// lobby tagged game = nascon, since app 480 (Spacewar) is shared with every other test game.
// Joiners find it in Steam's lobby list or through a friend's invite, join it, and say
// hello to its owner, who gives them a slot. Steam's lobby updates say when someone leaves.
// oNet lets Steam run and reads its packets every frame (net_steam_pump), and its
// Async - Steam event hands Steam's replies to net_steam_async.
//   joiner -> host:  hello (sent again each second until the host's lobby arrives)
#macro NET_GAME_TAG "nascon"
#macro NET_STEAM_TIMEOUT 10000  // joined online: give up on a silent host after this many ms
global.net_invite = 0;          // a friend's invite (a Steam lobby ID), taken up when the menus are next open

function net_steam_ok() {
	return steam_initialised();
}

// A Steam name the pixel font can draw: capitals, digits and spaces.
function net_clean_name(_s, _max) {
	_s = string_upper(_s);
	var _o = "";
	for (var _i = 1; _i <= string_length(_s) && string_length(_o) < _max; _i++) {
		var _k = ord(string_char_at(_s, _i));
		if ((_k >= 65 && _k <= 90) || (_k >= 48 && _k <= 57) || _k == 32) _o += chr(_k);
	}
	_o = string_trim(_o);
	return (_o == "") ? "PLAYER" : _o;
}

// Whether the Steam reply in async_load worked.
function net_steam_success() {
	var _ok = async_load[? "success"];
	if (!is_undefined(_ok)) return bool(_ok);
	return async_load[? "result"] == 1;
}

// ----- Hosting online -----
function net_steam_host_open() {
	var _n = net_ensure();
	if (_n.role == "host") return global.net_mode == "steam";
	if (_n.role == "client") net_drop("");
	if (!net_steam_ok()) {
		global.net_status = "STEAM ISN'T RUNNING";
		return false;
	}
	global.net_mode = "steam";
	_n.role = "host";
	_n.steam_lobby = 0;   // until Steam says it's made (lobby_created)
	global.net_role = "host";
	global.net_status = "OPENING ONLINE...";
	steam_lobby_create(steam_lobby_type_public, LOBBY_MAX);
	return true;
}

// What the online game list shows about this lobby. Set when it's made and once a second.
function net_steam_tag_lobby() {
	if (!net_online_open() || oNet.steam_lobby == 0) return;
	steam_lobby_set_data("game", NET_GAME_TAG);
	steam_lobby_set_data("host", net_clean_name(steam_get_persona_name(), 14));
	steam_lobby_set_data("players", string(array_length(global.lobby_slots)));
	steam_lobby_set_data("in_match", global.net_in_match ? "1" : "0");
}

// Host, once a second (run as oNet): a backup for a missed "left" update. A player who's
// missing from the Steam lobby two checks running has gone.
function net_steam_check_members() {
	if (steam_lobby == 0) return;
	var _in = [];
	for (var _i = 0; _i < steam_lobby_get_member_count(); _i++) array_push(_in, steam_lobby_get_member_id(_i));
	for (var _i = array_length(global.lobby_slots) - 1; _i >= 1; _i--) {
		if (global.lobby_kind[_i] != "player") continue;
		var _p = global.lobby_sock[_i];
		var _k = string(_p);
		if (array_contains(_in, _p)) {
			steam_missing[$ _k] = 0;
			continue;
		}
		steam_missing[$ _k] = (variable_struct_exists(steam_missing, _k) ? steam_missing[$ _k] : 0) + 1;
		if (steam_missing[$ _k] >= 2) {
			variable_struct_remove(steam_missing, _k);
			net_host_on_disconnect(_p);
		}
	}
}

// ----- Joining online -----
// The online game list (the join screen): NASCON lobbies anywhere in the world.
function net_steam_join_open(_keep_status = false) {
	var _n = net_ensure();
	if (_n.role == "host") net_host_close();
	global.net_mode = "steam";
	_n.steam_games = [];
	_n.browsing = true;
	if (!net_steam_ok()) {
		global.net_status = "STEAM ISN'T RUNNING";
		return;
	}
	net_steam_list();
	if (_keep_status && global.net_status != "") return;
	global.net_status = "LOOKING FOR GAMES ONLINE...";
}

// Ask Steam for the list again (oNet does this every few seconds while it's up).
function net_steam_list() {
	if (!net_steam_ok()) return;
	with (net_ensure()) {
		listing = true;
		list_at = current_time;
	}
	steam_lobby_list_add_string_filter("game", NET_GAME_TAG, steam_lobby_list_filter_eq);
	steam_lobby_list_add_distance_filter(steam_lobby_list_distance_filter_worldwide);
	steam_lobby_list_request();
}

// Join a Steam lobby, from the list or an invite. The rest happens in net_steam_async.
function net_steam_join(_lobby) {
	var _n = net_ensure();
	if (_n.role == "host") net_host_close();
	if (_n.role == "client") net_drop("");
	if (!net_steam_ok()) {
		global.net_status = "STEAM ISN'T RUNNING";
		return;
	}
	global.net_mode = "steam";
	_n.role = "client";
	_n.connecting = true;   // until Steam says we're in (lobby_joined)
	_n.sock = -1;
	_n.last_heard = current_time;
	global.net_role = "client";
	global.net_my_slot = -1;
	global.net_status = "JOINING...";
	steam_lobby_join_id(_lobby);
}

// Begin Step (run as oNet): let Steam run its callbacks, then read every packet that's
// arrived. Online, the host takes hellos and controls; a joiner only listens to its host.
function net_steam_pump() {
	if (!net_steam_ok()) return;
	steam_update();
	var _online = global.net_mode == "steam" && role != "none";
	var _b = buffer_create(1024, buffer_grow, 1);
	while (steam_net_packet_receive()) {
		if (!_online) continue;   // not playing online: just take them off the queue
		var _from = steam_net_packet_get_sender_id();
		steam_net_packet_get_data(_b);
		var _msg = net_read(_b);
		if (is_undefined(_msg) || !is_struct(_msg) || !variable_struct_exists(_msg, "t")) continue;
		if (role == "host") {
			if (_msg.t == "hello") {
				if (net_slot_of(_from) < 0) net_host_on_connect(_from); else net_send_lobby();
			} else {
				net_host_on_data(_from, _msg);
			}
		} else if (role == "client" && !connecting && _from == sock) {
			last_heard = current_time;
			net_client_on_data(_msg);
		}
	}
	buffer_delete(_b);
}

// Async - Steam (run as oNet): lobbies made, joined, listed and left, and invites.
function net_steam_async() {
	switch (async_load[? "event_type"]) {
		case "lobby_created":
			if (role != "host" || global.net_mode != "steam") {
				if (role == "none" && net_steam_success()) steam_lobby_leave();   // closed before Steam made it
				break;
			}
			if (!net_steam_success()) {
				net_host_close();
				global.net_status = "COULDN'T OPEN ONLINE";
				break;
			}
			steam_lobby = async_load[? "lobby_id"];
			global.net_status = "";
			if (array_length(global.lobby_names) > 0) global.lobby_names[0] = net_clean_name(steam_get_persona_name(), 12);
			net_steam_tag_lobby();
			net_lobby_changed();
			break;

		case "lobby_joined":
			if (role == "client" && global.net_mode == "steam" && connecting) {
				if (!net_steam_success()) {
					net_drop("COULDN'T JOIN THAT GAME");
					break;
				}
				if (steam_lobby_is_owner()) {   // its host left before we got in
					net_drop("THAT GAME HAS ENDED");
					break;
				}
				connecting = false;
				steam_lobby = async_load[? "lobby_id"];
				sock = steam_lobby_get_owner_id();
				last_heard = current_time;
				net_send(sock, { t: "hello" });
			} else if (role == "none" && net_steam_success()) {
				steam_lobby_leave();   // gave up on joining before Steam got us in
			}
			break;

//made by azlaan[exabyte909], mohib, and umer 
		case "lobby_list":
			if (!listing) break;
			listing = false;
			list_at = current_time;
			steam_games = [];
			for (var _i = 0; _i < steam_lobby_list_get_count(); _i++) {
				var _players = steam_lobby_list_get_lobby_member_count(_i);
				try { _players = real(steam_lobby_list_get_data(_i, "players")); } catch (_e) {}
				array_push(steam_games, {
					lobby: steam_lobby_list_get_lobby_id(_i),
					host: net_clean_name(steam_lobby_list_get_data(_i, "host"), 14),
					players: _players,
					in_match: steam_lobby_list_get_data(_i, "in_match") == "1",
				});
			}
			// Only swap the searching messages, never the reason we left a game.
			var _none = "NO GAMES FOUND YET. A FRIEND CAN ALSO INVITE YOU.";
			if (array_length(steam_games) == 0 && global.net_status == "LOOKING FOR GAMES ONLINE...") global.net_status = _none;
			if (array_length(steam_games) > 0 && global.net_status == _none) global.net_status = "LOOKING FOR GAMES ONLINE...";
			break;

		case "lobby_chat_update":
			// Someone left the lobby (2), dropped out (4), or was kicked or banned (8, 16).
			if ((async_load[? "change_flags"] & 30) == 0 || global.net_mode != "steam") break;
			var _who = async_load[? "user_id"];
			if (role == "host" && net_slot_of(_who) >= 0) net_host_on_disconnect(_who);
			else if (role == "client" && !connecting && _who == sock) net_drop("LOST CONNECTION TO THE HOST");
			break;

		case "lobby_join_requested":
			// A friend's invite was accepted, or Join Game on the friends list. The menus take it up.
			global.net_invite = async_load[? "lobby_id"];
			break;
	}
}

// ---------- Match over LAN ----------
// Host-authoritative: only the host runs the match. When it presses PLAY, each joiner gets
// "start" with the island's seed and builds the same island. From then on a joiner sends
// its controls every frame ("in"), and the host sends everyone a snapshot every
// NET_SNAP_EVERY frames ("snap"): every body, the match clock, and the events since the
// last one. A joiner's bodies are puppets that slide between snapshots, and the host's
// events (crumbling tiles, hits on trees and boulders, the kill feed) are applied as they
// arrive. When the host's match ends, its lobby says so and joiners go back to it.

// One body's state for a snapshot (run as the body). Short names keep the packets small.
function net_body_state() {
	var _s = {
		p: player_id, k: (object_index == oIsoDummy) ? 1 : 0, c: body_col,
		x: fx, y: fy, f: facing, fl: falling, fd: fall_dy, ft: fall_timer,
		l: lives_left, e: eliminated, hf: hit_flash, lp: lives_pop,
	};
	if (object_index == oIsoPlayer) {
		_s.b = build;
		_s.sh = shadow_timer;
		_s.cs = chain_state; _s.ct = chain_t; _s.ca = chain_ang_end; _s.cl = chain_len_max;
		_s.cc = chain_scale; _s.cd = chain_side; _s.cu = chain_cut;
		_s.pk = pu_kind; _s.pl = pu_left; _s.c3 = chain_triple;
		_s.ht = heat; _s.fi = fire_timer; _s.ad = ability_cd; _s.am = ability_cd_max; _s.rf = rewind_flash;
		var _rt = (build == BUILD.TIME) ? rewind_target() : undefined;
		if (!is_undefined(_rt)) { _s.hx = _rt[0]; _s.hy = _rt[1]; }
	}
	return _s;
}

// Host, End Step: send the snapshot to everyone playing.
function net_send_snapshot() {
	if (global.net_role != "host" || !global.net_in_match || array_length(global.net_match_socks) == 0 || !instance_exists(oIsoWorld)) {
		global.net_out_events = [];
		return;
	}
	var _b = [];
	with (oIsoPlayer) array_push(_b, net_body_state());
	with (oIsoDummy) array_push(_b, net_body_state());
	var _snap = {
		t: "snap",
		m: {
			mc: global.match_countdown, fr: global.match_frame, mp: global.match_players,
			mo: global.match_over, mt: global.match_timer,
			mw: instance_exists(global.match_winner) ? global.match_winner.player_id : -1,
			sk: global.shake,
		},
		b: _b,
		ev: global.net_out_events,
	};
	var _buf = net_write(_snap);
	for (var _i = 0; _i < array_length(global.net_match_socks); _i++) net_send_buffer(global.net_match_socks[_i], _buf);
	buffer_delete(_buf);
	global.net_out_events = [];
}

// Joiner: your controls this frame, to the host.
function net_client_send_input(_in) {
	net_client_send({ t: "in", mx: _in.move_x, my: _in.move_y, ax: _in.aim_gx, ay: _in.aim_gy, w: _in.whip, a: _in.ability });
}

// Joiner, Begin Step: apply the host's events, then the newest snapshot.
function net_client_apply() {
	if (!global.net_client_match || !global.net_client_ready || !instance_exists(oIsoWorld)) return;
	for (var _i = 0; _i < array_length(global.net_event_queue); _i++) {
		var _e = global.net_event_queue[_i];
		array_push(global.event_log, _e);
		if (array_length(global.event_log) > EVENT_LOG_MAX) array_delete(global.event_log, 0, 1);
		event_apply(_e);
	}
	global.net_event_queue = [];

	var _s = global.net_snap;
	if (is_undefined(_s)) return;
	global.net_snap = undefined;

	// Every body in the snapshot: made the first time it shows up, then updated.
	var _seen = {};
	for (var _i = 0; _i < array_length(_s.b); _i++) {
		var _b = _s.b[_i];
		_seen[$ string(_b.p)] = true;
		var _o = iso_body_by_pid(_b.p);
		if (instance_exists(_o) && ((_o.object_index == oIsoDummy) != (_b.k == 1))) {
			instance_destroy(_o);
			_o = noone;
		}
		if (!instance_exists(_o)) {
			var _vars = { gx: floor(_b.x + 0.5), gy: floor(_b.y + 0.5), player_id: _b.p, net_puppet: true };
			if (_b.k == 1) {
				_o = instance_create_depth(0, 0, 0, oIsoDummy, _vars);
			} else {
				_vars.net_local = (_b.p == global.net_my_pid);   // yours: the camera follows it and it reads your keys
				_vars.build = _b.b;
				_o = instance_create_depth(0, 0, 0, oIsoPlayer, _vars);
			}
		}
		with (_o) body_puppet_apply(_b);
	}
	with (oIsoPlayer) if (!variable_struct_exists(_seen, string(player_id))) instance_destroy();
	with (oIsoDummy) if (!variable_struct_exists(_seen, string(player_id))) instance_destroy();

	var _m = _s.m;
	global.match_countdown = _m.mc;
	global.match_frame = _m.fr;
	global.match_players = _m.mp;
	global.match_over = _m.mo;
	global.match_timer = _m.mt;
	global.match_winner = iso_body_by_pid(_m.mw);
	// Screen shake: whenever the host's goes up (a hit, a crumble), shake here as hard.
	if (_m.sk > global.net_last_shake + 0.5) global.shake = max(global.shake, _m.sk);
	global.net_last_shake = _m.sk;
}

// Joiner: copy one body's snapshot onto its puppet (run as the body).
function body_puppet_apply(_b) {
	if (body_col != _b.c) {
		var _ci = array_get_index(global.body_colours, _b.c);
		if (_ci >= 0) body_set_colour(_ci);
		else {
			body_col = _b.c;
			body_name = "PLAYER";
			body_tint = merge_colour(c_white, body_col, 0.6);
		}
	}
	facing = _b.f;
	falling = _b.fl;
	fall_timer = _b.ft;
	lives_left = _b.l;
	eliminated = _b.e;
	hit_flash = _b.hf;
	lives_pop = _b.lp;
	// Slide from where it's drawn now to the new spot. The first snapshot, or a jump
	// (respawning, a Time rewind), snaps straight there.
	if (net_t < 0 || point_distance(net_nx, net_ny, _b.x, _b.y) > 2) {
		fx = _b.x;
		fy = _b.y;
		fall_dy = _b.fd;
	}
	net_px = fx; net_py = fy; net_pd = fall_dy;
	net_nx = _b.x; net_ny = _b.y; net_nd = _b.fd;
	net_t = 0;

	if (object_index != oIsoPlayer) return;
	build = _b.b;
	if (variable_struct_exists(_b, "pk")) { pu_kind = _b.pk; pu_left = _b.pl; chain_triple = _b.c3; }
	shadow_timer = _b.sh;
	is_shadow = shadow_timer > 0;
	heat = _b.ht;
	fire_timer = _b.fi;
	ability_cd = _b.ad;
	ability_cd_max = _b.am;
	if (_b.rf > rewind_flash) rewind_flash = _b.rf;
	history = variable_struct_exists(_b, "hx") ? [[_b.hx, _b.hy]] : [];
	chain_ang_end = _b.ca;
	chain_len_max = _b.cl;
	chain_scale = _b.cc;
	chain_side = _b.cd;
	chain_cut = _b.cu;
	// The chain animates locally between snapshots; it only resyncs when its phase changes.
	if (_b.cs != chain_state) {
		var _was = chain_state;
		chain_state = _b.cs;
		chain_t = _b.ct;
		if (chain_state == 1) chain_build(chain_t);
		else if (chain_state == 2 && _was != 1) chain_build(1);
		// The tip cracked: the same puff the host shows.
		if (_was == 1 && chain_state == 2 && chain_cut == chain_segs && array_length(chain_pts) > chain_segs) {
			audio_whip_tile();
			var _tip = chain_pts[chain_segs];
			var _offs = chain_offsets();   // each tip of a triple whip
			for (var _o = 0; _o < array_length(_offs); _o++) {
				chain_off = _offs[_o];
				var _tx = iso_to_screen_x(chain_grid_x(_tip), chain_grid_y(_tip));
				var _ty = iso_to_screen_y(chain_grid_x(_tip), chain_grid_y(_tip));
				repeat (10) {
					array_push(sparks, {
						px: _tx, py: _ty - 4,
						vx: random_range(-2.5, 2.5), vy: random_range(-3, 0.5),
						life: irandom_range(8, 16),
					});
				}
			}
			chain_off = 0;
		}
	}
}

// Joiner, every Step: slide a puppet towards its newest snapshot (run as the body).
function body_puppet_step() {
	if (hit_flash > 0) hit_flash--;
	if (lives_pop > 0) lives_pop--;
	if (net_t < 0) return;
	net_t++;
	var _k = min(1, net_t / NET_SNAP_EVERY);
	fx = lerp(net_px, net_nx, _k);
	fy = lerp(net_py, net_ny, _k);
	fall_dy = lerp(net_pd, net_nd, _k);
	gx = floor(fx + 0.5);
	gy = floor(fy + 0.5);
	x = iso_to_screen_x(fx, fy);
	y = iso_to_screen_y(fx, fy);
	depth = -(fx + fy) * 100 - 50;
}

// ---------- Audio ----------
// Levels, triggers and fades come from GAME_ADDITIONS.md. Every file peaks near 0 dB and
// the game only ever turns sounds down: gain = 10^(dB / 20), never above 1.
// Music: Migi on the menus, Galaxy from the lobby on (to get everyone hyped) and through
// the match. Each music voice has a fader f (0 to 1) and plays at level * f^3, so fades
// creep in instead of jumping. The main bus carries a low-pass that muffles the menus and
// a reverb for the launch swell and the Time warp. Everything lives in globals, so the
// music carries on across room restarts.
#macro MUS_MIGI_START 10       // seconds: both songs open near silent, so they start and loop from here
#macro MUS_GALAXY_START 18     // Galaxy gets good at 0:18
#macro AUD_MUFFLE_HZ 700       // low-pass on the menus (not the main menu) and the pause screen
#macro AUD_OPEN_HZ 20000
global.aud = undefined;
global.music_duck = 1;   // 0 to 1, lowered while the ABOUT trailer plays
global.clash_next = 0;         // the two whip clashes take turns
global.fx_tick = 0;            // goes up once a frame (see body_fx_tick)

function aud_db(_db) {
	return power(10, _db / 20);
}

function aud_track(_snd, _db, _start) {
	return { snd: _snd, level: aud_db(_db), start: _start, voice: -1, f: 0, target: 0, step: 0, delay: 0 };
}

function audio_init() {
	if (!is_undefined(global.aud)) return;
	audio_sound_loop_start(mus_migi, MUS_MIGI_START);
	audio_sound_loop_start(mus_galaxy, MUS_GALAXY_START);
	var _lpf = audio_effect_create(AudioEffectType.LPF2, { cutoff: AUD_OPEN_HZ, q: 1, bypass: true });
	var _rev = audio_effect_create(AudioEffectType.Reverb1, { size: 0.85, damp: 0.4, mix: 0, bypass: true });
	audio_bus_main.effects[0] = _lpf;
	audio_bus_main.effects[1] = _rev;
	global.aud = {
		migi: aud_track(mus_migi, -11.2, MUS_MIGI_START),
		galaxy: aud_track(mus_galaxy, -17, MUS_GALAXY_START),
		wind: aud_track(snd_wind, -9.8, 0),
		music: -1,            // 0 Migi, 1 Galaxy, -1 before the first
		in_match: false,
		lpf: _lpf,
		rev: _rev,
		cut: AUD_OPEN_HZ,     // low-pass cutoff before the Time warp
		launch: -1,           // frames into the launch reverb, -1 when off
		warp: 0,              // frames left of the Time warp
	};
}

// Fade a track to _target (0 or 1) over _frames, after waiting _delay frames.
function aud_fade(_tr, _target, _frames, _delay = 0) {
	_tr.target = _target;
	_tr.step = 1 / max(1, _frames);
	_tr.delay = _delay;
}

function aud_track_step(_tr, _pitch) {
	if (_tr.delay > 0) { _tr.delay--; return; }
	if (_tr.target > 0 && _tr.voice < 0) _tr.voice = audio_play_sound(_tr.snd, 10, true, 0, _tr.start);
	if (_tr.f < _tr.target) _tr.f = min(_tr.target, _tr.f + _tr.step);
	else if (_tr.f > _tr.target) _tr.f = max(_tr.target, _tr.f - _tr.step);
	if (_tr.voice < 0) return;
	if (_tr.f <= 0 && _tr.target <= 0) {
		audio_stop_sound(_tr.voice);
		_tr.voice = -1;
		return;
	}
	audio_sound_gain(_tr.voice, _tr.level * power(_tr.f, 3) * global.set_music / 10 * global.music_duck, 0);   // MUSIC setting
	audio_sound_pitch(_tr.voice, _pitch);
}

// Every frame, from oIsoWorld's Step: picks the song, runs the fades and moves the bus effects.
function audio_step() {
	audio_init();
	global.fx_tick++;
	// Music ducks down while the trailer plays and comes back after.
	var _duck = (instance_exists(oIsoMenu) && oIsoMenu.trailer_open) ? 0.1 : 1;
	global.music_duck = lerp(global.music_duck, _duck, 0.08);
	var _a = global.aud;
	var _screen = instance_exists(oIsoMenu) ? oIsoMenu.screen : -1;

	var _want = (!global.menu_open || _screen == MENU.LOBBY) ? 1 : 0;
	if (_want != _a.music) {
		var _new = _want ? _a.galaxy : _a.migi;
		var _old = _want ? _a.migi : _a.galaxy;
		if (_a.music == -1) {
			aud_fade(_new, 1, 240);                         // game start: fade in over 4 s, no wait
		} else if (_want == 1) {
			aud_fade(_old, 0, 150);                         // into the lobby: cross-dissolve over 2.5 s
			aud_fade(_new, 1, 150);
		} else {
			aud_fade(_old, 0, 150);                         // back to the menus: wait 0.6 s, then fade in over 4 s
			aud_fade(_new, 1, 240, 35);
		}
		_a.music = _want;
	}

	// A match starting: the launch reverb swells and the wind comes in. Back to a menu: the wind goes.
	var _match = !global.menu_open;
	if (_match != _a.in_match) {
		if (_match) {
			_a.launch = 0;
			aud_fade(_a.wind, 1, 240, 70);
		} else {
			aud_fade(_a.wind, 0, 150);
		}
		_a.in_match = _match;
	}

	// Low-pass: slides in log-frequency, 5% of the way each frame, so the sweep sounds even.
	// Not while the ABOUT trailer plays: its sound goes through the same bus.
	var _trailer = instance_exists(oIsoMenu) && oIsoMenu.trailer_open;
	var _muffle = ((global.menu_open && _screen != MENU.MAIN) || global.pause_open) && !_trailer;
	_a.cut = exp(lerp(ln(_a.cut), ln(_muffle ? AUD_MUFFLE_HZ : AUD_OPEN_HZ), 0.05));
	var _cut = _a.cut;

	// Launch reverb: up to 0.6 over 40 frames, then dies away over 300.
	var _mix = 0;
	if (_a.launch >= 0) {
		_a.launch++;
		if (_a.launch <= 40) _mix = 0.6 * _a.launch / 40;
		else if (_a.launch < 340) _mix = 0.6 * sqr(1 - (_a.launch - 40) / 300);
		else _a.launch = -1;
	}

	// Time warp: on at once, full for 2 s, back to normal over the last 1 s. The wetter reverb wins.
	var _pitch = 1;
	if (_a.warp > 0) {
		_a.warp--;
		var _k = min(1, _a.warp / 60);
		_cut = exp(lerp(ln(_cut), ln(1200), _k));
		_mix = max(_mix, 0.75 * _k);
		_pitch = lerp(1, 0.8, _k);
	}

	_a.lpf.cutoff = _cut;
	_a.lpf.bypass = _cut > AUD_OPEN_HZ * 0.95;
	_a.rev.mix = _mix;
	_a.rev.bypass = _mix <= 0.001;
	aud_track_step(_a.migi, _pitch);
	aud_track_step(_a.galaxy, _pitch);
	aud_track_step(_a.wind, 1);   // the warp slows the music, not the wind
}

// One-off sound at _db, with a random pitch change of up to +/- _var.
// _pitch is the base pitch; _var is how far it wanders either side of it.
function sfx_play(_snd, _db, _var = 0, _pitch = 1) {
	audio_init();
	return audio_play_sound(_snd, 5, false, aud_db(_db) * global.set_sfx / 10, 0, _pitch * random_range(1 - _var, 1 + _var));   // SFX setting
}

function sfx_clash() {
	if (global.clash_next == 0) sfx_play(snd_clash_1, -16.7, 0.05);
	else sfx_play(snd_clash_2, -19.8, 0.05);   // a hotter file, so a lower gain: both land at the same loudness
	global.clash_next = 1 - global.clash_next;
}

function audio_ui_click() { sfx_play(snd_click, -7); }
// Your own whip swing. Only your game plays it: nobody hears anyone else's.
// Your whip's tip landing on a ground tile (run as the player). Only your own game plays it,
// like the swing, and not when the tip cracks over a hole.
function audio_whip_tile() {
	if (!is_local || array_length(chain_pts) <= chain_segs) return;
	var _tip = chain_pts[chain_segs];
	if (iso_has_floor(floor(chain_grid_x(_tip) + 0.5), floor(chain_grid_y(_tip) + 0.5))) sfx_play(snd_tile_hit, -20, 0.06);   // was -10: much quieter, as asked
}
function audio_whip() { sfx_play(snd_whip, -15.2, 0.05, 0.67); }   // deep (about 7 semitones down), and quieter than the first -9 dB (x0.75, x0.9, x0.8, then x0.9)
function audio_ui_hover() { sfx_play(snd_hover, -17); }

function audio_time_warp() {
	audio_init();
	global.aud.warp = 180;
}

// ---------- Particles ----------
// Pixel effects strips, 6 frames each; each sprite holds fire, shadow, then time (build * 6 + frame).
// Every effect frame shows for FX_FRAME game frames, and fades over its last 20 frames.
// They're all started from game events, so everyone on LAN sees them.
#macro FX_FRAME 7
#macro FX_ABILITY_FRAMES 84    // the circle and aura play twice
#macro FX_SPARK_FRAMES 42      // each kill spark plays once

function fx_alpha(_t, _dur) {
	return clamp((_dur - _t) / 20, 0, 1);
}

// Advance this body's effects one frame (run as the body). Called from Draw, which can
// run twice for a falling body, so it only counts once per frame.
function body_fx_tick() {
	if (fx_last_tick == global.fx_tick) return;
	fx_last_tick = global.fx_tick;
	if (ab_fx_t >= 0) {
		ab_fx_t++;
		if (ab_fx_t >= FX_ABILITY_FRAMES) ab_fx_t = -1;
	}
	if (kill_fx_left > 0) {
		// A new spark every 6 frames, on a ring around the body's middle, squashed for the iso view.
		if (kill_fx_left mod 6 == 0) {
			var _ang = random(360), _r = random_range(20, 32);
			array_push(kill_fx, { ox: lengthdir_x(_r, _ang), oy: -28 + lengthdir_y(_r, _ang) * 0.6, t: 0 });
		}
		kill_fx_left--;
	}
	for (var _i = array_length(kill_fx) - 1; _i >= 0; _i--) {
		kill_fx[_i].t++;
		if (kill_fx[_i].t >= FX_SPARK_FRAMES) array_delete(kill_fx, _i, 1);
	}
}

// The ability circle on the ground at the feet, at 2x, drawn under the body.
function draw_ability_circle() {
	if (ab_fx_t < 0) return;
	var _sub = ab_fx_build * 6 + (ab_fx_t div FX_FRAME) mod 6;
	draw_sprite_ext(sAbilityCircle, _sub, x, y, 2, 2, 0, c_white, fx_alpha(ab_fx_t, FX_ABILITY_FRAMES));
}

// The ability aura over the body, at 2x from the feet up. Drawn a row at a time so it
// fades out as it climbs: the bottom row is solid, the top one clear.
function draw_ability_aura() {
	if (ab_fx_t < 0) return;
	var _sub = ab_fx_build * 6 + (ab_fx_t div FX_FRAME) mod 6;
	var _a = fx_alpha(ab_fx_t, FX_ABILITY_FRAMES);
	var _left = x - 16 * 2, _top = y - 30 * 2;
	for (var _r = 0; _r < 32; _r++) {
		draw_sprite_part_ext(sAbilityAura, _sub, 0, _r, 32, 1, _left, _top + _r * 2, 2, 2, c_white, _a * _r / 31);
	}
}

// The killer's sparks: native 16 px, barely visible (alpha 0.25), in their build's colours.
function draw_kill_sparks() {
	var _n = array_length(kill_fx);
	if (_n == 0) return;
	var _b = clamp(build, 0, 2);
	for (var _i = 0; _i < _n; _i++) {
		var _s = kill_fx[_i];
		draw_sprite_ext(sKillSparks, _b * 6 + (_s.t div FX_FRAME) mod 6, round(x + _s.ox), round(y + _s.oy), 1, 1, 0, c_white, 0.25 * fx_alpha(_s.t, FX_SPARK_FRAMES));
	}
}

// ---------- Sky drops: fireballs and power-ups ----------
// Every DROP_EVERY frames of a match the host drops something on a random standing tile.
// It hovers high above it, spinning, for 3 seconds while that tile flashes in its colour
// (red for a fireball, blue for speed, gold for triple whip), then falls. A fireball sets the tile alight, so it
// crumbles like a Fire whip's, and pushes anyone close a little. A power-up sits on the
// tile until a player walks over it, or fades after DROP_LIFE. You can hold one power-up
// at a time, and it stacks with your build. Spawns, landings and pickups are events, so
// LAN and Steam players see the same drops; their games just animate them.
#macro DROP_EVERY 900          // power-ups: 15 seconds apart at the start of a match
#macro DROP_EVERY_MIN 360      // down to 6 seconds
#macro DROP_RAMP 7200          // over the first 2 minutes after GO, then it stays there
#macro DROP_HOVER 180          // 3 seconds hovering and spinning
#macro DROP_FALL 16            // frames to fall
#macro DROP_HEIGHT 200         // pixels above the tile it hovers
#macro DROP_LIFE 600           // a power-up nobody takes fades after 10 seconds
#macro FIREBALL_RADIUS 1.5     // tiles: bodies this close to the impact get pushed
#macro FIREBALL_FORCE 0.2      // the push right at the impact (a whip is 0.345), half that at the edge
#macro PU_SPEED_FRAMES 180     // speed boost: 3 seconds
#macro PU_SPEED_MULT 1.5
#macro PU_TRIPLE_SWINGS 3      // triple whip: three lashes, then it's gone
#macro TRIPLE_GAP 0.8          // tiles between the three whips of a triple whip
#macro TRIPLE_KNOCK 1.25        // a triple whip knocks 25% harder
enum DROP { FIREBALL, SPEED, TRIPLE }
global.drops = [];             // { n, kind, gx, gy, t, landed, age }
global.drop_parts = [];        // pixel particles { px, py, vx, vy, life, col }
global.drop_rings = [];        // fireball shockwaves { px, py, t }
global.drop_sounds = [];       // fireball whooshes to stop once faded { v, t }
global.drop_timer = 0;         // power-ups
global.drop_fire_timer = 0;    // fireballs, on their own timer
global.drop_clock = 0;         // frames since GO, for the ramp
global.drop_next = 0;          // the host numbers drops so events can name them

function drops_reset() {
	global.drops = [];
	global.drop_parts = [];
	global.drop_rings = [];
	for (var _i = 0; _i < array_length(global.drop_sounds); _i++) audio_stop_sound(global.drop_sounds[_i].v);
	global.drop_sounds = [];
	global.drop_timer = 0;
	global.drop_fire_timer = 0;
	global.drop_clock = 0;
	global.drop_next = 0;
}

// Index of drop number _n in global.drops, or -1.
function drop_find(_n) {
	for (var _i = 0; _i < array_length(global.drops); _i++) if (global.drops[_i].n == _n) return _i;
	return -1;
}

// Each kind's colours: [core, glow].
function drop_cols(_kind) {
	switch (_kind) {
		case DROP.FIREBALL: return [make_colour_rgb(255, 150, 40), make_colour_rgb(255, 60, 20)];
		case DROP.SPEED:    return [make_colour_rgb(140, 235, 255), make_colour_rgb(50, 150, 255)];
		default:            return [make_colour_rgb(255, 225, 120), make_colour_rgb(240, 160, 30)];
	}
}

// How high a drop's orb is above its tile, in pixels.
function drop_height(_d) {
	if (_d.landed) return 0;
	if (_d.t < DROP_HOVER) return DROP_HEIGHT + sin(_d.t / 12) * 6;
	var _k = min(1, (_d.t - DROP_HOVER) / DROP_FALL);
	return DROP_HEIGHT * (1 - _k * _k);
}

// A puff of _n pixels at screen (_x, _y) in a kind's colours.
function drop_burst(_x, _y, _n, _kind, _speed) {
	var _c = drop_cols(_kind);
	repeat (_n) {
		var _a = random(360), _s = random_range(0.5, _speed);
		array_push(global.drop_parts, { px: _x, py: _y, vx: lengthdir_x(_s, _a), vy: lengthdir_y(_s, _a) * 0.6 - 0.8, life: irandom_range(14, 30), col: choose(_c[0], _c[1], c_white) });
	}
}

// Frames between fireballs, _t frames after GO: 15 s at GO, 4 s at 1 minute, 3 s at
// 1.5 minutes and 2 s from 2 minutes on, in straight lines between those.
function fireball_every(_t) {
	var _pts = [[0, 900], [3600, 240], [5400, 180], [7200, 120]];
	for (var _i = 1; _i < array_length(_pts); _i++) {
		var _a = _pts[_i - 1], _b = _pts[_i];
		if (_t <= _b[0]) return round(lerp(_a[1], _b[1], (_t - _a[0]) / (_b[0] - _a[0])));
	}
	return 120;
}

// Host: drop a _kind on a random standing tile that isn't burning and has nothing else coming.
function drop_spawn(_kind) {
	var _spots = [];
	for (var _gx = 0; _gx < global.iso_w; _gx++) {
		for (var _gy = 0; _gy < global.iso_h; _gy++) {
			if (!iso_walkable(_gx, _gy) || global.iso_burn[_gx][_gy] > 0) continue;
			var _taken = false;
			for (var _i = 0; _i < array_length(global.drops); _i++) if (global.drops[_i].gx == _gx && global.drops[_i].gy == _gy) _taken = true;
			if (!_taken) array_push(_spots, [_gx, _gy]);
		}
	}
	if (array_length(_spots) == 0) return;
	var _s = _spots[irandom(array_length(_spots) - 1)];
	game_event("drop_spawn", { n: global.drop_next, kind: _kind, gx: _s[0], gy: _s[1] });
	global.drop_next++;
}

// Host only, from match_step: the drop timers, landings, pickups and fading.
function drops_host_step() {
	if (match_locked() || global.match_over) return;
	global.drop_clock++;
	// Power-ups: 15 s apart at GO, steadily more often until 6 s apart from 2 minutes in.
	global.drop_timer++;
	if (global.drop_timer >= round(lerp(DROP_EVERY, DROP_EVERY_MIN, min(1, global.drop_clock / DROP_RAMP)))) {
		global.drop_timer = 0;
		drop_spawn(choose(DROP.SPEED, DROP.TRIPLE));
	}
	// Fireballs, on their own timer (see fireball_every).
	global.drop_fire_timer++;
	if (global.drop_fire_timer >= fireball_every(global.drop_clock)) {
		global.drop_fire_timer = 0;
		drop_spawn(DROP.FIREBALL);
	}
	for (var _i = array_length(global.drops) - 1; _i >= 0; _i--) {
		var _d = global.drops[_i];
		if (!_d.landed) {
			if (_d.t < DROP_HOVER + DROP_FALL) continue;
			game_event("drop_land", { n: _d.n });
			if (_d.kind == DROP.FIREBALL) {
				// The tile burns and crumbles like the Fire whip's, and anyone close is pushed away.
				iso_ignite_tile(_d.gx, _d.gy);
				var _all = iso_bodies();
				for (var _b = 0; _b < array_length(_all); _b++) {
					var _who = _all[_b];
					if (_who.eliminated || _who.falling) continue;
					var _dist = point_distance(_who.fx, _who.fy, _d.gx, _d.gy);
					if (_dist > FIREBALL_RADIUS) continue;
					var _force = FIREBALL_FORCE * (1 - 0.5 * _dist / FIREBALL_RADIUS);
					with (_who) body_knock(_d.gx, _d.gy, _force);
				}
			}
			continue;
		}
		// A power-up on the ground: gone if its tile is, or after DROP_LIFE.
		if (!iso_has_floor(_d.gx, _d.gy) || _d.age >= DROP_LIFE) {
			game_event("drop_gone", { n: _d.n });
			continue;
		}
		// The first player to walk over it who isn't already holding one takes it.
		with (oIsoPlayer) {
			if (eliminated || falling || pu_kind >= 0) continue;
			if (point_distance(fx, fy, _d.gx, _d.gy) > 0.6) continue;
			game_event("drop_grab", { n: _d.n, player: player_id, kind: _d.kind });
			break;
		}
	}
}

// Every game, every frame of a match: drops count up, and their particles move.
function drops_step() {
	for (var _i = 0; _i < array_length(global.drops); _i++) {
		var _d = global.drops[_i];
		var _sx = iso_to_screen_x(_d.gx, _d.gy), _sy = iso_to_screen_y(_d.gx, _d.gy);
		if (_d.landed) {
			_d.age++;
			if (random(1) < 0.15) drop_burst(_sx + random_range(-8, 8), _sy - 16, 1, _d.kind, 0.6);
			continue;
		}
		_d.t++;
		// Embers off a fireball, sparkles off a power-up.
		var _oy = _sy - 14 - drop_height(_d);
		if (random(1) < ((_d.kind == DROP.FIREBALL) ? 0.8 : 0.35)) {
			var _c = drop_cols(_d.kind);
			array_push(global.drop_parts, { px: _sx + random_range(-7, 7), py: _oy + random_range(-7, 7), vx: random_range(-0.4, 0.4), vy: random_range(-0.9, -0.2), life: irandom_range(12, 24), col: choose(_c[0], _c[1]) });
		}
	}
	for (var _i = array_length(global.drop_parts) - 1; _i >= 0; _i--) {
		var _p = global.drop_parts[_i];
		_p.px += _p.vx;
		_p.py += _p.vy;
		_p.vx *= 0.92;
		_p.vy = _p.vy * 0.92 + 0.03;
		_p.life--;
		if (_p.life <= 0) array_delete(global.drop_parts, _i, 1);
	}
	for (var _i = array_length(global.drop_sounds) - 1; _i >= 0; _i--) {
		var _fs = global.drop_sounds[_i];
		_fs.t--;
		if (_fs.t > 0) continue;
		audio_stop_sound(global.drop_sounds[_i].v);
		array_delete(global.drop_sounds, _i, 1);
	}
	for (var _i = array_length(global.drop_rings) - 1; _i >= 0; _i--) {
		global.drop_rings[_i].t++;
		if (global.drop_rings[_i].t >= 24) array_delete(global.drop_rings, _i, 1);
	}
}

// A quad turned _ang degrees, filled with _col.
function draw_spin_quad(_x, _y, _r, _ang, _col) {
	draw_set_colour(_col);
	draw_primitive_begin(pr_trianglefan);
	for (var _k = 0; _k < 4; _k++) draw_vertex(_x + lengthdir_x(_r, _ang + _k * 90), _y + lengthdir_y(_r, _ang + _k * 90));
	draw_primitive_end();
}

// One drop's orb at screen (_x, _y): a glow, a spinning gem, and a mark for power-ups.
function draw_drop_orb(_x, _y, _kind, _sc, _ang, _alpha) {
	var _c = drop_cols(_kind);
	gpu_set_blendmode(bm_add);
	draw_set_alpha(0.55 * _alpha);
	draw_circle_colour(_x, _y, 20 * _sc, _c[1], c_black, false);
	draw_set_alpha(1);
	gpu_set_blendmode(bm_normal);
	draw_set_alpha(_alpha);
	draw_spin_quad(_x, _y, 12 * _sc, _ang, c_black);
	draw_spin_quad(_x, _y, 10 * _sc, _ang, _c[1]);
	draw_spin_quad(_x, _y, 6 * _sc, -_ang * 1.5, _c[0]);
	if (_kind == DROP.FIREBALL) {
		draw_set_colour(make_colour_rgb(255, 240, 180));
		draw_circle(_x + random_range(-1, 1), _y + random_range(-1, 1), 2 * _sc, false);
	} else if (_kind == DROP.SPEED) {
		pixel_text(_x + 1, _y - 7 * _sc, ">", max(1, round(2 * _sc)), c_white, fa_center);
	} else {
		// Triple whip: three little whips side by side, each with a dark outline and a tip.
		for (var _k = -1; _k <= 1; _k++) {
			var _wx = _x + _k * 5 * _sc;
			draw_set_colour(c_black);
			draw_line_width(_wx - 2.5 * _sc, _y + 6 * _sc, _wx + 2.5 * _sc, _y - 6 * _sc, 3 * _sc);
			draw_set_colour(c_white);
			draw_line_width(_wx - 2 * _sc, _y + 5 * _sc, _wx + 2 * _sc, _y - 5 * _sc, 1.5 * _sc);
			draw_circle(_wx + 2.5 * _sc, _y - 6 * _sc, 1.5 * _sc, false);
		}
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

// oIsoWorld Draw End: each drop's landing glow, shadow and orb, then the particles.
function draw_drops() {
	for (var _i = 0; _i < array_length(global.drops); _i++) {
		var _d = global.drops[_i];
		var _sx = iso_to_screen_x(_d.gx, _d.gy), _sy = iso_to_screen_y(_d.gx, _d.gy);
		var _tile = global.iso_floor[_d.gx][_d.gy];
		var _h = drop_height(_d);
		// The tile it will land on pulses, faster as it gets close.
		if (!_d.landed && _tile != -1) {
			var _k = min(1, _d.t / (DROP_HOVER + DROP_FALL));
			var _pulse = 0.5 + 0.5 * sin(_d.t * (0.08 + 0.3 * _k));
			// Strongly coloured in the drop's own colour: a tinted layer, then an added glow on top.
			var _gcs = drop_cols(_d.kind);
			var _gc = _gcs[1];
			var _str = (0.3 + 0.7 * _pulse) * (0.5 + 0.5 * _k);
			draw_sprite_ext(sIsoTile, _tile, _sx, _sy, 1, 1, 0, _gc, 0.55 * _str);
			gpu_set_blendmode(bm_add);
			draw_sprite_ext(sIsoTile, _tile, _sx, _sy, 1, 1, 0, _gc, 0.8 * _str);
			gpu_set_blendmode(bm_normal);
		}
		// Its shadow grows as it comes down.
		var _near = 1 - _h / DROP_HEIGHT;
		draw_set_alpha(0.12 + 0.25 * _near);
		draw_set_colour(c_black);
		draw_ellipse(_sx - 6 - 8 * _near, _sy - 3 - 3 * _near, _sx + 6 + 8 * _near, _sy + 3 + 3 * _near, false);
		draw_set_alpha(1);
		// A power-up on the ground bobs and turns slowly, and blinks out over its last second.
		var _a = 1, _oy = _sy - 14 - _h, _ang = _d.t * 6;
		if (_d.landed) {
			_oy += sin(_d.age / 10) * 2;
			_ang = _d.age * 2;
			if (_d.age > DROP_LIFE - 60) _a = ((_d.age div 4) mod 2 == 0) ? (DROP_LIFE - _d.age) / 60 : 0.2;
		}
		draw_drop_orb(_sx, _oy, _d.kind, 1, _ang, _a);
	}
	for (var _i = 0; _i < array_length(global.drop_rings); _i++) {
		var _r = global.drop_rings[_i];
		var _k = _r.t / 24;
		draw_set_alpha(1 - _k);
		draw_set_colour(make_colour_rgb(255, 140, 40));
		draw_ellipse(_r.px - 10 - 70 * _k, _r.py - 5 - 35 * _k, _r.px + 10 + 70 * _k, _r.py + 5 + 35 * _k, true);
	}
	for (var _i = 0; _i < array_length(global.drop_parts); _i++) {
		var _p = global.drop_parts[_i];
		draw_set_alpha(min(1, _p.life / 8));
		draw_set_colour(_p.col);
		draw_rectangle(_p.px - 1, _p.py - 1, _p.px + 1, _p.py + 1, false);
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

// A faint glow at the feet and rising pixels while a player holds a power-up (run as the player).
function draw_powerup_aura() {
	if (pu_kind < 0 || falling) return;
	var _c = drop_cols(pu_kind);
	gpu_set_blendmode(bm_add);
	draw_set_alpha(0.3 + 0.15 * sin(current_time / 150));
	draw_ellipse_colour(x - 20, y - 8, x + 20, y + 8, _c[1], c_black, false);
	draw_set_alpha(1);
	gpu_set_blendmode(bm_normal);
	draw_set_colour(_c[0]);
	for (var _i = 0; _i < 4; _i++) {
		var _rise = (current_time / 20 + _i * 17) mod 44;
		draw_set_alpha(0.7 * (1 - _rise / 44));
		draw_rectangle(x - 11 + _i * 7, y - 4 - _rise, x - 10 + _i * 7, y - 3 - _rise, false);
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

// ---------- Clouds ----------
// sCloud: 20 pixel clouds on one 252x58 canvas. Three layers, far to near, drifting right and
// wrapping. Further layers follow the camera more (par), so they read as further away.
#macro CLOUD_SPAN 1700
function iso_make_clouds() {
	var _out = [];
	//        count scale  speed       par   alpha tint
	var _layers = [
		[12, 1, 0.08, 0.18, 0.6,  0.55, make_colour_rgb(196, 218, 245)],   // far
		[10, 1, 0.22, 0.38, 0.35, 0.8,  make_colour_rgb(226, 238, 252)],   // mid
		[6,  2, 0.40, 0.65, 0.15, 0.95, c_white],                          // near
	];
	for (var _l = 0; _l < array_length(_layers); _l++) {
		var _L = _layers[_l];
		repeat (_L[0]) {
			array_push(_out, {
				cx: global.iso_origin_x + random_range(-CLOUD_SPAN, CLOUD_SPAN),
				cy: global.iso_origin_y + random_range(-300, 1100),
				scale: _L[1], spd: random_range(_L[2], _L[3]), par: _L[4], alpha: _L[5], col: _L[6],
				flip: choose(-1, 1), frame: irandom(19),
			});
		}
	}
	return _out;
}
