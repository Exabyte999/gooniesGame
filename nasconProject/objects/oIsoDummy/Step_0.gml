// On a joiner's game it just follows the host's snapshots (see Match over LAN in scr_iso).
if (net_puppet) { body_puppet_step(); exit; }
if (global.menu_open || eliminated) exit;
if (lives_pop > 0) lives_pop--;

// Falling off the island: drop out of sight, lose a life, then come back.
// Out of stars means eliminated: it stays gone.
if (falling) {
	body_fall_step();
	if (fall_timer > 70) {
		body_lose_life();
		if (!eliminated) respawn();
	}
	exit;
}

body_knock_step();

gx = floor(fx + 0.5);
gy = floor(fy + 0.5);
x = iso_to_screen_x(fx, fy);
y = iso_to_screen_y(fx, fy);
depth = -(fx + fy) * 100 - 50;

if (!iso_has_floor(gx, gy)) {
	body_start_fall();
}
