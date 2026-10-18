if (global.menu_open) exit;
if (global.set_hud) {   // HUD can be turned off in settings
	draw_lives_hud();
	draw_kill_feed();
}
draw_match_countdown();   // the build pick and GO, over the HUD
if (!global.set_hud) exit;
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_set_valign(fa_top);
draw_set_font(-1);
var _help = "WASD / arrows: move    Left click: whip chain    Mouse wheel: zoom";
if (global.build >= 0) _help += "    Space: ability";
draw_text(16, 16, _help);
draw_text(16, 40, "Mouse tile: " + string(hover_gx) + ", " + string(hover_gy));
if (instance_exists(oIsoPlayer)) {
	draw_text(16, 64, "Player tile: " + string(oIsoPlayer.gx) + ", " + string(oIsoPlayer.gy));
}
