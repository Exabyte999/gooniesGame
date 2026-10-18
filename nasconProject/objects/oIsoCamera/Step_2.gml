// End Step, so the player has already moved this frame.
if (mouse_wheel_up())   zoom = max(0.5, zoom - 0.1);
if (mouse_wheel_down()) zoom = min(2, zoom + 0.1);

// Follow your own player. Once you're eliminated, fly around freely to spectate.
var _me = noone;
with (oIsoPlayer) if (is_local) _me = id;
if (instance_exists(_me) && _me.eliminated) {
	if (!global.menu_open && !global.pause_open) {
		var _ix = _me.input.move_x;
		var _iy = _me.input.move_y;
		var _len = max(1, point_distance(0, 0, _ix, _iy));
		cam_x += _ix / _len * spectate_speed * zoom;
		cam_y += _iy / _len * spectate_speed * zoom;
		// Don't drift too far from the island.
		var _cx = iso_to_screen_x(global.iso_w / 2, global.iso_h / 2);
		var _cy = iso_to_screen_y(global.iso_w / 2, global.iso_h / 2);
		cam_x = clamp(cam_x, _cx - 1050, _cx + 1050);
		cam_y = clamp(cam_y, _cy - 750, _cy + 750);
	}
} else if (instance_exists(_me)) {
	cam_x = lerp(cam_x, _me.x, follow_speed);
	cam_y = lerp(cam_y, _me.y - 16, follow_speed);
}

// Shake from chain hits and crumbling tiles.
var _shx = 0;
var _shy = 0;
if (global.shake > 0.3) {
	_shx = random_range(-global.shake, global.shake);
	_shy = random_range(-global.shake, global.shake);
	global.shake *= 0.85;
} else {
	global.shake = 0;
}

// Match the screen's shape if the resolution or fullscreen setting changed.
var _rs = settings_render_size();
view_h = view_w * _rs[1] / _rs[0];

var _w = view_w * zoom;
var _h = view_h * zoom;
camera_set_view_size(cam, _w, _h);
camera_set_view_pos(cam, round(cam_x - _w / 2 + _shx), round(cam_y - _h / 2 + _shy));
