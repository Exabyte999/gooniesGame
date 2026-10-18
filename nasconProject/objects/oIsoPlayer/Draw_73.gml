// Draw End: the chain goes on top of everything so trees and boulders never hide it.
body_draw_tag();   // "P0" under your feet

// Puffs where the whip cracks, and the Time rewind trail
for (var _i = array_length(sparks) - 1; _i >= 0; _i--) {
	var _p = sparks[_i];
	_p.px += _p.vx;
	_p.py += _p.vy;
	_p.vx *= 0.88;
	_p.vy *= 0.88;
	_p.life--;
	if (_p.life <= 0) { array_delete(sparks, _i, 1); continue; }
	draw_set_alpha(min(1, _p.life / 6));
	draw_set_colour(variable_struct_exists(_p, "col") ? _p.col : c_white);
	draw_rectangle(_p.px - 1, _p.py - 1, _p.px + 1, _p.py + 1, false);
}
draw_set_alpha(1);

// Fire: the chain goes from steel grey to glowing orange as it heats up.
var _hot = (build == BUILD.FIRE) ? heat / 100 : 0;
var _dark = merge_colour(make_colour_rgb(40, 38, 46), make_colour_rgb(150, 40, 10), _hot);
var _lite_a = merge_colour(make_colour_rgb(160, 160, 176), make_colour_rgb(255, 200, 80), _hot);
var _lite_b = merge_colour(make_colour_rgb(112, 112, 128), make_colour_rgb(240, 110, 30), _hot);
var _glow = (build == BUILD.FIRE && heat >= heat_glow);

if (chain_state != 0 && array_length(chain_pts) > chain_segs) {
	// Reeling back slides the chain in towards the hand.
	var _k = (chain_state == 2) ? 1 - chain_t * chain_t : 1;
	var _px = x + 6 * facing;
	var _py = y - 26;
	for (var _i = 1; _i <= chain_cut; _i++) {
		var _p = chain_pts[_i];
		var _q = [_p[0] * _k, _p[1] * _k, _p[2] * _k];
		var _gx = chain_grid_x(_q);
		var _gy = chain_grid_y(_q);
		var _lx = iso_to_screen_x(_gx, _gy);
		var _ly = iso_to_screen_y(_gx, _gy) - _q[1] * chain_lift;
		var _w = lerp(5, 2, _i / chain_segs);   // thick at the handle, thin at the tip
		if (_glow) {
			gpu_set_blendmode(bm_add);
			draw_set_colour(make_colour_rgb(120, 50, 0));
			draw_line_width(_px, _py, _lx, _ly, _w + 6);
			gpu_set_blendmode(bm_normal);
		}
		draw_set_colour(_dark);
		draw_line_width(_px, _py, _lx, _ly, _w + 1);
		draw_set_colour((_i mod 2 == 0) ? _lite_a : _lite_b);
		draw_line_width(_px, _py, _lx, _ly, max(1, _w - 1));
		_px = _lx;
		_py = _ly;
	}
	// Tip
	draw_set_colour(_dark);
	draw_circle(_px, _py, 3, false);
	draw_set_colour(_lite_a);
	draw_circle(_px - 1, _py - 1, 1, false);
}

// A hot chain smoulders in your hand even when you're not whipping.
if (_glow && !falling && random(1) < 0.3) {
	array_push(sparks, { px: x + 6 * facing + random_range(-2, 2), py: y - 26, vx: random_range(-0.3, 0.3), vy: random_range(-1.2, -0.5), life: irandom_range(10, 20), col: choose(make_colour_rgb(255, 160, 40), make_colour_rgb(255, 220, 120)) });
}

draw_set_alpha(1);
draw_set_colour(c_white);
