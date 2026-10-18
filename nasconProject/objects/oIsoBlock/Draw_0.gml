draw_prop_shadow();   // soft shadow on the grass (see scr_iso)
var _a = max(0, image_alpha);
var _ox = (shake > 0) ? random_range(-shake, shake) : 0;
draw_sprite_ext(sprite_index, image_index, x + _ox, y, 1, 1, sway, c_white, _a);

// Cracks spread over a damaged boulder (3 levels per boulder shape).
if (is_boulder && hp < max_hp) {
	var _lvl = min(2, floor((max_hp - hp) * 3 / max_hp));
	draw_sprite_ext(sIsoBoulderCrack, floor(image_index) * 3 + _lvl, x + _ox, y, 1, 1, 0, c_white, _a);
}

for (var _i = 0; _i < array_length(parts); _i++) {
	var _p = parts[_i];
	draw_set_alpha(min(1, _p.life / 15));
	draw_set_colour(_p.col);
	draw_rectangle(_p.px, _p.py, _p.px + _p.size, _p.py + _p.size, false);
}
draw_set_alpha(1);
draw_set_colour(c_white);
