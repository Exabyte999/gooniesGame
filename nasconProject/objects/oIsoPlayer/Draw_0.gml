if (eliminated) exit;
// Once below the ground, the island draws this in between its tiles instead (see oIsoWorld Draw).
if (falling && fall_dy > 0 && !global.iso_drawing_fallers) exit;
var _alpha = falling ? max(0, 1 - fall_timer / 50) : 1;
body_fx_tick();   // ability and kill effects (see Particles in scr_iso)

// Stand the sprite on the tile centre whatever its origin is.
var _sx = draw_scale * facing;
var _sy = draw_scale;
var _w = sprite_get_width(sprite_index);
var _h = sprite_get_height(sprite_index);
var _ox = sprite_get_xoffset(sprite_index);
var _oy = sprite_get_yoffset(sprite_index);
var _dx = (_ox - _w / 2) * _sx;
var _dy = (_oy - _h) * _sy;

// Time: a faint echo shows where a rewind would take you. Only you see yours.
var _g = (is_local && build == BUILD.TIME && ability_cd == 0 && !falling) ? rewind_target() : undefined;
if (!is_undefined(_g)) {
	var _gxs = iso_to_screen_x(_g[0], _g[1]);
	var _gys = iso_to_screen_y(_g[0], _g[1]);
	draw_sprite_ext(sprite_index, image_index, _gxs + _dx, _gys + _dy, _sx, _sy, 0, make_colour_rgb(240, 204, 104), 0.25);
}

draw_ability_circle();   // on the ground, under you

// Ground shadow
if (!falling) {
	draw_set_alpha(0.3);
	draw_set_colour(c_black);
	draw_ellipse(x - 14, y - 6, x + 14, y + 6, false);
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

if (is_shadow) {
	// Shadow form: a dark, see-through silhouette with wisps rising off it.
	var _k = shadow_timer / shadow_frames;
	draw_sprite_ext(sprite_index, image_index, x + _dx, y + fall_dy + _dy, _sx, _sy, 0, make_colour_rgb(60, 30, 110), 0.45 * _alpha);
	draw_set_colour(make_colour_rgb(110, 70, 180));
	for (var _i = 0; _i < 5; _i++) {
		var _px = x - 12 + _i * 6 + round(sin(current_time / 120 + _i) * 2);
		var _py = y - 10 - ((current_time / 25 + _i * 13) mod 40);
		draw_set_alpha(0.5 * _k);
		draw_rectangle(_px, _py, _px + 1, _py + 1, false);
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
} else {
	draw_sprite_ext(sprite_index, image_index, x + _dx, y + fall_dy + _dy, _sx, _sy, 0, body_tint, _alpha);
}

// Time: flash as you arrive.
if (rewind_flash > 0) {
	gpu_set_blendmode(bm_add);
	draw_sprite_ext(sprite_index, image_index, x + _dx, y + _dy, _sx, _sy, 0, make_colour_rgb(240, 204, 104), rewind_flash / 15);
	gpu_set_blendmode(bm_normal);
}

// Over you: the ability aura and, after a kill, your sparks.
draw_ability_aura();
draw_kill_sparks();
