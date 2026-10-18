// Draw End: its player number under its feet, and a "-1" that rises after losing a star.
body_draw_tag();
if (falling || lives_pop <= 0) exit;
var _top = y - sprite_get_height(sprite_index) * draw_scale - 18;
draw_set_alpha(min(1, lives_pop / 15));
pixel_text(x, _top - 10 + lives_pop / 2, "-1", 2, body_col, fa_center);
draw_set_alpha(1);
draw_set_colour(c_white);
