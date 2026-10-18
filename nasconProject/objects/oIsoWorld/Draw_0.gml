// Sky gradient behind everything, sized to whatever the camera sees.
var _cam = view_camera[0];
var _vx = camera_get_view_x(_cam);
var _vy = camera_get_view_y(_cam);
var _vw = camera_get_view_width(_cam);
var _vh = camera_get_view_height(_cam);
var _sky_top = make_colour_rgb(92, 160, 230);
var _sky_bottom = make_colour_rgb(200, 232, 255);
draw_rectangle_colour(_vx, _vy, _vx + _vw, _vy + _vh, _sky_top, _sky_top, _sky_bottom, _sky_bottom, false);

// Clouds, far to near. Each layer is pulled along with the camera by its par, rounded to whole pixels.
var _ccx = _vx + _vw / 2, _ccy = _vy + _vh / 2;
for (var _i = 0; _i < array_length(clouds); _i++) {
	var _c = clouds[_i];
	var _dx = round(_c.cx + (_ccx - global.iso_origin_x) * _c.par);
	var _dy = round(_c.cy + (_ccy - global.iso_origin_y) * _c.par);
	draw_sprite_ext(sCloud, _c.frame, _dx, _dy, _c.scale * _c.flip, _c.scale, 0, _c.col, _c.alpha);
}
draw_set_colour(c_white);

// Island, back to front. Under each tile hangs a short column of rock chunks
// that fade into the sky the deeper they go, finished with a shallow V tip.
// Each tile owns its column, so a crumbling tile drops its rock with it.
// Tiles go one diagonal at a time so anything falling through a hole or off the
// edge can be slotted in between: tiles behind it stay behind, tiles in front cover it.
var _fallers = [];
var _bodies = iso_bodies();
for (var _i = 0; _i < array_length(_bodies); _i++) {
	if (_bodies[_i].falling && _bodies[_i].fall_dy > 0) array_push(_fallers, _bodies[_i]);
}
array_sort(_fallers, function(_a, _b) { return (_a.fx + _a.fy) - (_b.fx + _b.fy); });
var _next = 0;
var _draw_faller = function(_who) {
	global.iso_drawing_fallers = true;
	with (_who) event_perform(ev_draw, 0);
	global.iso_drawing_fallers = false;
};
for (var _s = 0; _s <= global.iso_w + global.iso_h - 2; _s++) {
	while (_next < array_length(_fallers) && _fallers[_next].fx + _fallers[_next].fy < _s - 0.5) {
		_draw_faller(_fallers[_next]);
		_next++;
	}
	for (var _gx = max(0, _s - (global.iso_h - 1)); _gx <= min(_s, global.iso_w - 1); _gx++) {
		var _gy = _s - _gx;
		var _tile = global.iso_floor[_gx][_gy];
		var _n, _dy = 0, _alpha = 1;
		if (_tile == -1) {
			var _chunk = global.iso_fall[_gx][_gy];
			if (!is_struct(_chunk)) continue;
			_tile = _chunk.tile;
			_n = _chunk.under;
			_dy = _chunk.dy;
			_alpha = _chunk.alpha;
		} else {
			_n = global.iso_under[_gx][_gy];
		}
		var _sx = iso_to_screen_x(_gx, _gy);
		var _sy = iso_to_screen_y(_gx, _gy) + _dy;
		draw_sprite_ext(sIsoTile, ISO_TILE.TIP + min(_n div 2, ISO_TILE.FADE_LEVELS - 1), _sx, _sy + 8 + _n * 12, 1, 1, 0, c_white, _alpha);
		for (var _k = _n; _k >= 1; _k--) {
			draw_sprite_ext(sIsoTile, ISO_TILE.ROCK + min((_k - 1) div 2, ISO_TILE.FADE_LEVELS - 1), _sx, _sy + 8 + (_k - 1) * 12, 1, 1, 0, c_white, _alpha);
		}
		draw_sprite_ext(sIsoTile, _tile, _sx, _sy, 1, 1, 0, c_white, _alpha);

		// Burning: a hot glow on the grass and flickering pixel flames.
		var _burn = (_dy == 0) ? global.iso_burn[_gx][_gy] : 0;
		if (_burn > 0) {
			var _heat = 1 - _burn / ISO_BURN_FRAMES;
			gpu_set_blendmode(bm_add);
			draw_sprite_ext(sIsoTile, _tile, _sx, _sy, 1, 1, 0, make_colour_rgb(150, 50, 0), 0.45 + 0.25 * _heat + 0.1 * sin(current_time / 90 + _gx));
			gpu_set_blendmode(bm_normal);
			for (var _f = 0; _f < 6; _f++) {
				var _fx = _sx + ((_gx * 37 + _gy * 11 + _f * 19) mod 40) - 20;
				var _fy = _sy + ((_gx * 13 + _gy * 29 + _f * 7) mod 16) - 8;
				var _fh = 4 + 6 * _heat + 3 * sin(current_time / 70 + _f * 1.7 + _gx);
				draw_set_colour(make_colour_rgb(200, 60, 20));
				draw_rectangle(_fx - 2, _fy - _fh, _fx + 2, _fy, false);
				draw_set_colour(make_colour_rgb(252, 160, 40));
				draw_rectangle(_fx - 1, _fy - _fh * 0.7, _fx + 1, _fy, false);
				draw_set_colour(make_colour_rgb(255, 230, 120));
				draw_rectangle(_fx, _fy - _fh * 0.35, _fx, _fy, false);
			}
			draw_set_colour(c_white);
		}

		// Cracks spread as the tile loses health.
		var _lost = ISO_TILE_HP - global.iso_hp[_gx][_gy];
		if (_dy == 0 && _lost > 0) draw_sprite(sIsoCrack, min(2, (_lost - 1) div 2), _sx, _sy);
	}
}
// Anything that fell off the front of the island goes in front of it all.
while (_next < array_length(_fallers)) {
	_draw_faller(_fallers[_next]);
	_next++;
}

if (iso_in_bounds(hover_gx, hover_gy) && global.iso_floor[hover_gx][hover_gy] != -1) {
	var _col = iso_walkable(hover_gx, hover_gy) ? c_white : c_red;
	draw_sprite_ext(sIsoCursor, 0, iso_to_screen_x(hover_gx, hover_gy), iso_to_screen_y(hover_gx, hover_gy), 1, 1, 0, _col, 1);
}
