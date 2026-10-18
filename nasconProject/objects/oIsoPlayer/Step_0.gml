// Your own whip's swing sound, on your game only. On a joiner your player is a puppet,
// so this watches chain_state change instead of the click.
if (is_local && chain_state == 1 && chain_state_was != 1) audio_whip();
chain_state_was = chain_state;

// A joiner's copy of a player just follows the host's snapshots (see Match over LAN in scr_iso).
if (net_puppet) {
	body_puppet_step();
	if (chain_state == 1) { chain_t = min(1, chain_t + 1 / chain_out_frames); chain_build(chain_t); }
	else if (chain_state == 2) chain_t = min(1, chain_t + 1 / chain_back_frames);
	if (rewind_flash > 0) rewind_flash--;
	exit;
}

// Nothing happens until a build is picked on the start menu.
if (global.menu_open) { ability_lock = 10; exit; }
if (eliminated) exit;
if (global.match_over) ability_lock = 2;   // no whipping or abilities on the win screen
if (match_locked()) { ability_lock = 2; exit; }   // waiting for GO
if (global.pause_open && is_local) ability_lock = 10;   // your pause menu is up: no whip or ability (and none from its clicks)
if (ability_lock > 0) ability_lock--;
if (rewind_flash > 0) rewind_flash--;
if (ability_cd > 0) ability_cd--;

// ---------- Abilities ----------
var _space = input.ability && ability_lock == 0;
switch (build) {
	case BUILD.FIRE:
		if (_space && ability_cd == 0 && !falling) {
			fire_timer = fire_frames;
			ability_cd_max = fire_frames + fire_cooldown_max;
			ability_cd = ability_cd_max;
			game_event("ability", { player: player_id, build: build, x: fx, y: fy });
		}
		if (fire_timer > 0) {
			fire_timer--;
			if (heat_idle > 0) heat_idle--;
			else heat = max(0, heat - heat_cool);
		}
		if (fire_timer == 0) heat = 0;   // the fire went out
		break;
	case BUILD.SHADOW:
		if (_space && ability_cd == 0 && !falling) {
			shadow_timer = shadow_frames;
			ability_cd_max = shadow_frames + shadow_cooldown_max;
			ability_cd = ability_cd_max;
			game_event("ability", { player: player_id, build: build, x: fx, y: fy });
		}
		if (shadow_timer > 0) shadow_timer--;
		is_shadow = shadow_timer > 0;
		break;
	case BUILD.TIME:
		if (_space && ability_cd == 0 && (!falling || fall_timer < rewind_grace)) {
			if (do_rewind()) {
				ability_cd_max = rewind_cooldown_max;
				ability_cd = ability_cd_max;
				game_event("ability", { player: player_id, build: build, x: fx, y: fy });
			}
		}
		break;
}

// Falling off the island: drop out of sight, then come back.
if (falling) {
	body_fall_step();
	if (fall_timer > 70) {
		body_lose_life();
		if (!eliminated) respawn();
	}
	exit;
}

// Knockback slides you, and you can be knocked off the edge.
body_knock_step();

// Movement is relative to the screen: up is up, right is right (from the input record).
var _ix = input.move_x;
var _iy = input.move_y;

var _dgx = 0;
var _dgy = 0;

if (_ix != 0 || _iy != 0) {
	// Screen-space velocity in pixels, then into grid units.
	var _len = point_distance(0, 0, _ix, _iy);
	var _spd = move_speed * (is_shadow ? shadow_speed : 1) * (knock_timer > 0 ? 0.35 : 1);
	var _vx = _ix / _len * _spd;
	var _vy = _iy / _len * _spd;
	_dgx = (_vx / ISO_HALF_W + _vy / ISO_HALF_H) / 2;
	_dgy = (_vy / ISO_HALF_H - _vx / ISO_HALF_W) / 2;
}

// Move each axis separately so you slide along walls.
if (_dgx != 0 && can_move(fx + _dgx, fy)) fx += _dgx;
if (_dgy != 0 && can_move(fx, fy + _dgy)) fy += _dgy;

var _screen_dx = _dgx - _dgy;
if (abs(_screen_dx) > 0.0001) facing = sign(_screen_dx);

gx = floor(fx + 0.5);
gy = floor(fy + 0.5);
x = iso_to_screen_x(fx, fy);
y = iso_to_screen_y(fx, fy);

// Blocks use -(gx + gy) * 100, so this puts the player in front of
// blocks behind it and behind blocks in front of it.
depth = -(fx + fy) * 100 - 50;

// The ground under you crumbled.
if (!iso_has_floor(gx, gy)) {
	body_start_fall();
	chain_state = 0;
	exit;
}

// Remember where you stood, for the Time rewind.
if (build == BUILD.TIME) {
	hist_tick++;
	array_push(history, [fx, fy, hist_tick]);
	if (array_length(history) > rewind_frames) array_delete(history, 0, 1);
}

// ---------- Chain ----------
if (chain_cooldown > 0) chain_cooldown--;

if (chain_state == 0 && chain_cooldown == 0 && ability_lock == 0 && input.whip) {
	if (build == BUILD.FIRE && fire_timer > 0) {
		heat = min(100, heat + heat_per_lash);
		heat_idle = heat_hold;
	}
	var _mx = input.aim_gx;
	var _my = input.aim_gy;
	chain_ang_end = point_direction(fx, fy, _mx, _my);
	chain_len_max = clamp(point_distance(fx, fy, _mx, _my), 2, chain_range);
	chain_side = -chain_side;
	chain_state = 1;
	chain_t = 0;
	chain_slow = 0;
	chain_cut = chain_segs;
	chain_hits = [];
	chain_cooldown = chain_cooldown_max;
	// Stretch the links so the tip lands exactly at the reach.
	chain_scale = 1;
	chain_build(1);
	chain_scale = chain_len_max / max(0.1, chain_pts[chain_segs][0]);
	chain_build(0);
	var _sx = iso_to_screen_x(_mx, _my);
	if (abs(_sx - x) > 2) facing = sign(_sx - x);
}

if (chain_state == 1) {
	chain_t = min(1, chain_t + (chain_slow > 0 ? chain_tree_slow : 1) / chain_out_frames);
	if (chain_slow > 0) chain_slow--;
	chain_build(chain_t);
	// Fire: a hotter chain hits harder (up to 3x).
	var _dmg = chain_damage + ((build == BUILD.FIRE) ? floor(heat / 40) : 0);

	// Players and the dummy get knocked away from you, harder by a hot Fire chain.
	// Anyone in shadow form lets the chain pass straight through.
	var _bodies = iso_bodies();
	var _force = knock_force + ((build == BUILD.FIRE) ? heat / 100 * knock_heat_bonus : 0);

	// Whatever the chain slaps down on gets hit.
	for (var _i = 1; _i <= chain_segs; _i++) {
		var _p = chain_pts[_i];
		if (_p[3] < 0.85 || _p[0] < 0.4) continue;   // still in the air, or at your feet
		var _lx = chain_grid_x(_p), _ly = chain_grid_y(_p);
		for (var _b = 0; _b < array_length(_bodies); _b++) {
			var _who = _bodies[_b];
			if (_who == id || _who.falling || _who.is_shadow || array_contains(chain_hits, _who)) continue;
			if (point_distance(_lx, _ly, _who.fx, _who.fy) > chain_hit_radius) continue;
			array_push(chain_hits, _who);
			// The tip hits harder: base force near the hand, rising to chain_tip_bonus x at the very tip.
			var _tipk = 1 + (chain_tip_bonus - 1) * sqr(_i / chain_segs);
			with (_who) body_knock(other.fx, other.fy, _force * _tipk, other.id);
			global.shake = max(global.shake, 4);
			repeat (8) {
				array_push(sparks, {
					px: iso_to_screen_x(_who.fx, _who.fy), py: iso_to_screen_y(_who.fx, _who.fy) - 24,
					vx: random_range(-3, 3), vy: random_range(-3, 1), life: irandom_range(8, 14),
					col: make_colour_rgb(255, 120, 120),
				});
			}
		}
		var _gx = floor(chain_grid_x(_p) + 0.5);
		var _gy = floor(chain_grid_y(_p) + 0.5);
		if (!iso_in_bounds(_gx, _gy) || (_gx == gx && _gy == gy)) continue;
		var _prop = global.iso_prop[_gx][_gy];
		if (!instance_exists(_prop) || _prop.broken) continue;
		var _new = !array_contains(chain_hits, _prop);
		if (_new) {
			array_push(chain_hits, _prop);
			game_event("prop_hit", { gx: _gx, gy: _gy, dmg: _dmg, side: chain_side, by: player_id });
		}
		if (_prop.is_boulder) {
			// Boulders stop the whip dead: cut it here and reel it back.
			chain_cut = _i;
			if (build == BUILD.FIRE && heat >= heat_glow) iso_ignite_tile(_gx, _gy, player_id);
			global.shake = max(global.shake, 3);
			chain_state = 2;
			chain_t = 0;
			break;
		}
		if (_new) chain_slow = 4;
	}

	if (chain_state == 1 && chain_t >= 1) {
		// The tip cracks.
		var _tip = chain_pts[chain_segs];
		var _tx = iso_to_screen_x(chain_grid_x(_tip), chain_grid_y(_tip));
		var _ty = iso_to_screen_y(chain_grid_x(_tip), chain_grid_y(_tip));
		repeat (10) {
			array_push(sparks, {
				px: _tx, py: _ty - 4,
				vx: random_range(-2.5, 2.5), vy: random_range(-3, 0.5),
				life: irandom_range(8, 16),
			});
		}
		global.shake = max(global.shake, 1.5);
		audio_whip_tile();   // on your own game only
		// Fire: a glowing chain sets the tile it cracks on alight.
		if (build == BUILD.FIRE && heat >= heat_glow) {
			var _tgx = floor(chain_grid_x(_tip) + 0.5), _tgy = floor(chain_grid_y(_tip) + 0.5);
			if (_tgx != gx || _tgy != gy) iso_ignite_tile(_tgx, _tgy, player_id);
		}
		chain_state = 2;
		chain_t = 0;
	}
} else if (chain_state == 2) {
	chain_t += 1 / chain_back_frames;
	if (chain_t >= 1) chain_state = 0;
}
