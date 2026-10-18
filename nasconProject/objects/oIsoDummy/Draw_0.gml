if (eliminated) exit;
// Once below the ground, the island draws this in between its tiles instead (see oIsoWorld Draw).
if (falling && fall_dy > 0 && !global.iso_drawing_fallers) exit;
var _alpha = falling ? max(0, 1 - fall_timer / 50) : 1;

// Stand the sprite on the tile centre whatever its origin is.
var _sx = draw_scale * facing;
var _sy = draw_scale;
var _w = sprite_get_width(sprite_index);
var _h = sprite_get_height(sprite_index);
var _dx = (sprite_get_xoffset(sprite_index) - _w / 2) * _sx;
var _dy = (sprite_get_yoffset(sprite_index) - _h) * _sy;

// Ground shadow
if (!falling) {
	draw_set_alpha(0.3);
	draw_set_colour(c_black);
	draw_ellipse(x - 14, y - 6, x + 14, y + 6, false);
	draw_set_alpha(1);
}

// Tinted with its player colour.
draw_sprite_ext(sprite_index, 0, x + _dx, y + fall_dy + _dy, _sx, _sy, 0, body_tint, _alpha);

// White flash when the whip connects.
if (hit_flash > 0) {
	gpu_set_blendmode(bm_add);
	draw_sprite_ext(sprite_index, 0, x + _dx, y + fall_dy + _dy, _sx, _sy, 0, c_white, hit_flash / 8);
	gpu_set_blendmode(bm_normal);
}
draw_set_colour(c_white);
