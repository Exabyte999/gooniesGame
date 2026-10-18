// A practice target. It stands still, gets knocked back by the whip with the
// same physics as the player, falls off the island and comes back.
// gx and gy are passed in by oIsoWorld.
fx = gx;
fy = gy;
radius = 0.25;
facing = -1;
draw_scale = 0.5;
image_speed = 0;
is_shadow = false;       // a real opponent's chain passes through while this is true

spawn_gx = gx;
spawn_gy = gy;
falling = false;
fall_dy = 0;
fall_vy = 0;
fall_timer = 0;

body_init(false);        // knockback, lives and colour (see scr_iso)

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
};

x = iso_to_screen_x(fx, fy);
y = iso_to_screen_y(fx, fy);
