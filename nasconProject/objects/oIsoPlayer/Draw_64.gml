// Build HUD, bottom left: icon, name, and the countdown or cooldown bar. Only yours.
if (!is_local || global.menu_open || build < 0 || match_picking()) exit;
var _gh = display_get_gui_height();
// Match over: the win screen replaces the build HUD and the spectating banner.
if (global.match_over) { draw_match_end(); exit; }
if (!global.set_hud) exit;   // HUD turned off in settings
if (eliminated) {
	// Spectating: a banner along the bottom instead of the ability bar.
	var _gw = display_get_gui_width();
	pixel_text(_gw / 2, _gh - 110, "ELIMINATED - SPECTATING", 4, body_col, fa_center);
	pixel_text(_gw / 2, _gh - 60, "WASD: MOVE    WHEEL: ZOOM    ESC: MENU", 2, c_white, fa_center);
	exit;
}
var _x = 24, _y = _gh - 112;
var _names = ["FIRE", "SHADOW", "TIME"];
var _cols = [make_colour_rgb(252, 140, 40), make_colour_rgb(176, 120, 255), make_colour_rgb(240, 204, 104)];
var _col = _cols[build];

draw_set_colour(c_black);
draw_rectangle(_x - 4, _y - 4, _x + 284, _y + 92, false);
draw_set_colour(_col);
draw_rectangle(_x, _y, _x + 280, _y + 88, false);
draw_set_colour(make_colour_rgb(26, 30, 52));
draw_rectangle(_x + 4, _y + 4, _x + 276, _y + 84, false);

var _ready = ability_cd == 0 || (build == BUILD.FIRE && fire_timer > 0);
draw_sprite_ext(sAbilityIcon, build, _x + 44, _y + 44, 4, 4, 0, _ready ? c_white : c_gray, 1);
pixel_text(_x + 88, _y + 14, _names[build], 3, _col, fa_left);

// Bar: Fire counts down while lit, then every build shows its cooldown.
var _bx = _x + 88, _by = _y + 50, _bw = 176, _bh = 20;
// The bar moves one step per second, exactly when the number does.
var _total, _left, _countdown, _label;
if (build == BUILD.FIRE && fire_timer > 0) {
	// Fire is lit: the bar counts down the seconds left.
	_countdown = true;
	_total = ceil(fire_frames / 60);
	_left = ceil(fire_timer / 60);
	_label = string(_left) + "S LEFT";
} else {
	// Cooldown: the bar refills one block per second. Fire's starts once it goes out.
	_countdown = false;
	_total = ceil(((build == BUILD.FIRE) ? fire_cooldown_max : ability_cd_max) / 60);
	_left = ceil(ability_cd / 60);
	_label = (ability_cd == 0) ? "SPACE: READY" : string(_left) + "S";
}
_total = max(1, _total);
var _blocks = _countdown ? _left : _total - min(_left, _total);
draw_set_colour(c_black);
draw_rectangle(_bx - 2, _by - 2, _bx + _bw + 2, _by + _bh + 2, false);
draw_set_colour(make_colour_rgb(50, 54, 80));
draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, false);
draw_set_colour(_col);
if (_blocks > 0) draw_rectangle(_bx, _by, _bx + round(_bw * _blocks / _total) - 1, _by + _bh, false);
pixel_text(_bx + _bw / 2, _by + 3, _label, 2, c_white, fa_center);
draw_set_colour(c_white);
