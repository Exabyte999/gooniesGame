// gx and gy are passed in by oIsoWorld when it creates the player.
fx = gx;              // exact grid position (tile centres are whole numbers)
fy = gy;
move_speed = 4;       // screen pixels per step
radius = 0.25;        // collision size in tiles
facing = 1;
draw_scale = 0.5;     // sPlayer is 64x128, half size fits a 64px tile

spawn_gx = gx;        // where to come back after falling off
spawn_gy = gy;
falling = false;
fall_dy = 0;
fall_vy = 0;
fall_timer = 0;
// LAN (see scr_iso): net_local false is someone else's player. On the host it's steered by
// what their game sends; on a joiner's game every player is a puppet of the host's.
if (!variable_instance_exists(id, "net_local")) net_local = true;
if (!variable_instance_exists(id, "build")) build = -1;   // set from the lobby when the match starts
chain_state_was = 0;       // last Step's chain_state, to catch your whip starting (for its sound)
build_picked = false;      // picked on the build pick screen (else the host gives a random one when it ends)
body_init(net_local);     // knockback, lives and colour, shared with the dummy (see scr_iso)
knock_force = 0.345;      // how hard your whip knocks a target, tiles per frame (was 0.3, +15%)
knock_heat_bonus = 0.2875;   // extra push from a fully heated Fire chain (was 0.25, +15%)

// Chain whip: left click cracks it towards the cursor. It winds up behind you,
// a loop rolls out along the chain, and it slaps down from your hand to the tip.
// Every tree or boulder it lands on gets hit once per lash: trees slow it a
// little, boulders stop it.
chain_range = 9;          // reach in tiles
chain_damage = 1;         // damage to each tree or boulder it hits
chain_out_frames = 10;    // how long the crack takes, wind-up to tip
chain_back_frames = 8;    // how long it takes to reel back in
chain_tree_slow = 0.7;    // speed while dragging through a tree
chain_cooldown_max = 18;  // frames between lashes
chain_hit_radius = 0.85;  // how close (in tiles) a landed link must be to hit someone (was 0.6, then 0.75)
chain_tip_bonus = 1.5;    // knockback at the very tip, times the normal force (the hand end is unchanged)
chain_lag = 1.4;          // how far behind the hand the tip follows (bigger = loopier)
chain_windup = 125;       // how far back over your shoulder it starts, in degrees
chain_lift = 14;          // screen pixels per tile of height, for drawing
chain_segs = 24;          // links in the chain
chain_cooldown = 0;
chain_state = 0;          // 0 idle, 1 cracking, 2 reeling back
chain_t = 0;              // 0..1 through the current phase
chain_side = 1;           // which side the loop leans to, flips every lash
chain_ang_end = 0;        // grid-space direction to the cursor (degrees)
chain_len_max = 0;        // how far this lash reaches, in tiles
chain_scale = 1;          // stretches the links so the tip lands on the target
chain_slow = 0;           // frames left of tree drag
chain_hits = [];          // props already hit this lash
chain_cut = chain_segs;   // links shown, fewer when a boulder stopped it
chain_pts = [];           // [forward, height, sideways, landed 0..1] for each link joint
sparks = [];              // little puff where the whip cracks

// Shape of the chain at time _t (0..1). Each link turns from pointing back
// over the shoulder to lying flat ahead, and links further out turn later,
// which makes the loop that rolls out to the tip.
chain_build = function(_t) {
	var _n = chain_segs;
	var _seg = chain_len_max * chain_scale * (0.45 + 0.55 * min(1, _t * 2.5)) / _n;
	var _f = 0, _z = 26 / chain_lift;   // starts at hand height
	chain_pts = [[_f, _z, 0]];
	for (var _i = 1; _i <= _n; _i++) {
		var _u = (_i - 0.5) / _n;
		var _tau = clamp(_t * (1 + chain_lag) - _u * chain_lag, 0, 1);
		var _e = _tau * _tau * (3 - 2 * _tau);
		var _phi = chain_windup * (1 - _e) - 45 * sqr(1 - _u) * _e - 30 * sin(pi * _e);
		_f += _seg * dcos(_phi);
		_z = max(0, _z + _seg * dsin(_phi));
		var _side = chain_side * 0.35 * sin(pi * _u) * sin(pi * min(1, _t * 1.3));
		// Once a link has landed it drops from the hand to the ground within a
		// tile or so, however short the lash is.
		var _land = (26 / chain_lift) * sqr(max(0, 1 - _f / 1.2));
		array_push(chain_pts, [_f, lerp(_z, min(_z, _land), _e), _side, _e]);
	}
};

// Grid position of a chain joint.
chain_grid_x = function(_p) { return fx + lengthdir_x(_p[0], chain_ang_end) + lengthdir_x(_p[2], chain_ang_end + 90); };
chain_grid_y = function(_p) { return fy + lengthdir_y(_p[0], chain_ang_end) + lengthdir_y(_p[2], chain_ang_end + 90); };

// True if a square of size radius around (_x, _y) only touches walkable tiles.
can_stand = function(_x, _y) {
	return iso_walkable(floor(_x - radius + 0.5), floor(_y - radius + 0.5))
		&& iso_walkable(floor(_x + radius + 0.5), floor(_y - radius + 0.5))
		&& iso_walkable(floor(_x - radius + 0.5), floor(_y + radius + 0.5))
		&& iso_walkable(floor(_x + radius + 0.5), floor(_y + radius + 0.5));
};

// How many of your four corners are over ground you could walk on.
stand_corners = function(_x, _y) {
	var _n = 0;
	for (var _i = 0; _i < 4; _i++) {
		var _cx = floor(_x + ((_i mod 2) ? radius : -radius) + 0.5);
		var _cy = floor(_y + ((_i div 2) ? radius : -radius) + 0.5);
		if (iso_walkable(_cx, _cy)) _n++;
	}
	return _n;
};

// Can you step to (_x, _y)? Onto ground you can stand on, yes. A knock (or a tile crumbling
// beside you) can leave a corner hanging over a hole while you're still on your feet, and
// from there no step at all would pass that test, so you'd freeze. So from there, any step
// that doesn't put more of you over the hole, or into a tree or boulder, is allowed too.
can_move = function(_x, _y) {
	if (can_stand(_x, _y)) return true;
	return !can_stand(fx, fy) && body_clear(_x, _y) && stand_corners(_x, _y) >= stand_corners(fx, fy);
};

// Back on the spawn tile, or the walkable tile nearest to it if that one is gone.
respawn = function() {
	var _best_x = spawn_gx, _best_y = spawn_gy, _best_d = infinity;
	for (var _gx = 0; _gx < global.iso_w; _gx++) {
		for (var _gy = 0; _gy < global.iso_h; _gy++) {
			if (!iso_walkable(_gx, _gy)) continue;
			var _d = point_distance(_gx, _gy, spawn_gx, spawn_gy);
			if (_d < _best_d) { _best_d = _d; _best_x = _gx; _best_y = _gy; }
		}
	}
	fx = _best_x;
	fy = _best_y;
	falling = false;
	fall_dy = 0;
	fall_vy = 0;
	kvx = 0;
	kvy = 0;
	history = [];
	prehit_tick = -1;
};

// ---------- Build abilities (this player's build, picked in the lobby) ----------
ability_lock = 0;          // short pause after the menu closes so its click/space don't fire
// Fire: Space lights the chain for a while. It heats up as you keep whipping.
fire_frames = 480;         // 8 seconds alight
fire_cooldown_max = 720;   // 12 seconds after it goes out
fire_timer = 0;
heat = 0;                  // 0..100
heat_per_lash = 20;        // heat gained per crack
heat_hold = 60;            // frames after a lash before it starts cooling
heat_cool = 0.6;           // heat lost per frame once cooling
heat_glow = 50;            // above this the chain glows and sets tiles alight
heat_idle = 0;
// Shadow: Space turns you into a shadow for a moment. Enemy chains pass through.
shadow_frames = 120;       // 2 seconds
shadow_cooldown_max = 360; // 6 seconds
shadow_speed = 1.55;       // move speed multiplier while a shadow (+55%)
shadow_timer = 0;
is_shadow = false;         // other players' chains should ignore you while true
// Time: Space jumps you back to where you stood a moment ago.
rewind_frames = 48;        // 0.8 seconds back
rewind_cooldown_max = 480; // 8 seconds
rewind_grace = 45;         // frames into a fall when you can still rewind
history = [];              // recent [fx, fy, hist_tick], oldest first (only frames on your feet)
hist_tick = 0;             // counts those frames, so a spot can be told apart from a hit
prehit_tick = -1;          // hist_tick when a hit started your slide, -1 if none lately
prehit_x = 0;              // where you stood when that hit landed
prehit_y = 0;
rewind_prehit_frames = 120;   // a hit within this many frames on your feet still counts
rewind_flash = 0;
ability_cd = 0;            // cooldown for the build's Space ability
ability_cd_max = 1;

// Where a rewind would take you: the spot from 0.8 seconds ago. But if a hit sent you
// sliding longer ago than that (so every remembered spot is on the slide), where you stood
// when that hit landed. The ground isn't checked: if the tile there has broken since, you
// still go there, and fall.
rewind_target = function() {
	if (net_puppet) return (array_length(history) > 0) ? [history[0][0], history[0][1]] : undefined;   // the host's pick
	if (prehit_tick >= 0 && hist_tick - prehit_tick <= rewind_prehit_frames
		&& (array_length(history) == 0 || history[0][2] > prehit_tick)) return [prehit_x, prehit_y];
	if (array_length(history) > 0) return [history[0][0], history[0][1]];
	return undefined;
};

// Time rewind: jump to rewind_target, with the hit's slide and slow-down gone.
do_rewind = function() {
	var _t = rewind_target();
	if (is_undefined(_t)) return false;
	// Leave a trail of afterimages between here and there.
	for (var _k = 0; _k < 8; _k++) {
		var _ax = lerp(fx, _t[0], _k / 8), _ay = lerp(fy, _t[1], _k / 8);
		array_push(sparks, { px: iso_to_screen_x(_ax, _ay), py: iso_to_screen_y(_ax, _ay) - 20, vx: 0, vy: -0.3, life: 14 + _k * 2, col: make_colour_rgb(240, 204, 104) });
	}
	fx = _t[0];
	fy = _t[1];
	falling = false;
	fall_dy = 0;
	fall_vy = 0;
	kvx = 0;
	kvy = 0;
	knock_timer = 0;
	history = [];
	prehit_tick = -1;
	rewind_flash = 15;
	// That tile broke since you stood there: you fall from it.
	if (!iso_has_floor(floor(fx + 0.5), floor(fy + 0.5))) body_start_fall();
	return true;
};

x = iso_to_screen_x(fx, fy);
y = iso_to_screen_y(fx, fy);
depth = -(fx + fy) * 100 - 50;
