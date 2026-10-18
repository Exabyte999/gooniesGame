// Builds the floating island, spawns props, the player and the camera.
depth = 10000; // ground draws behind everything standing on it
global.iso_drawing_fallers = false;   // true while the island draws a falling body (see Draw)

// Saved video settings, applied once when the game starts.
if (!global.settings_loaded) {
	settings_load();
	settings_apply();
	global.settings_loaded = true;
}
global.kill_feed = [];   // fresh feed every match
match_reset();
global.pause_open = false;

// Push the room's background colour layer behind the ground, or it covers it.
var _bg = layer_get_id("Background");
if (_bg != -1) layer_depth(_bg, 16000);

// Edit this to change the level. One string per row (gy), one character per tile (gx).
//   .  grass        T  oak tree       Y  pine tree      P  player start
//   B  boulder 1x1  H  boulder 2x1 (along gx)  V  boulder 1x2 (along gy)
//   O  boulder 2x2  -- big boulders go on their back (top-left) tile and
//                      cover the tiles after them, which should be "."
//   (space) open sky: nothing to stand on
var _layout = [
	"          ...         ",
	"         .....        ",
	"        Y......       ",
	"       .......B       ",
	"      ........T       ",
	"     .Y.........      ",
	"    .............     ",
	"    ......O.......    ",
	"   .............V..   ",
	"   ..T..............  ",
	"   ........P.....T..  ",
	"   ................   ",
	"   .Y..........Y...   ",
	"   ....T...........   ",
	"   ......Y..H.....    ",
	"   ...B...........    ",
	"    .....  .......    ",
	"             ...      ",
];

// Random island test: each match builds a new island from one seed. The layout above stays as the fallback.
randomise();
if (ISO_RANDOM_MAP) {
	global.iso_seed = (global.iso_next_seed >= 0) ? global.iso_next_seed : irandom(999999);
	global.iso_next_seed = -1;
	_layout = iso_generate_layout(global.iso_seed);
}

// sIsoTile frames
// ROCK and TIP each have FADE_LEVELS frames, from earthy brown to almost sky blue.
enum ISO_TILE { GRASS = 0, GRASS_DARK = 1, ROCK = 2, TIP = 8, FADE_LEVELS = 6 }
// sIsoBlock frames
enum ISO_TREE { OAK = 0, PINE = 1 }
// sIsoBoulder frames, and the tiles each one covers (offsets from its back tile)
enum ISO_BOULDER { SMALL = 0, LONG_X = 1, LONG_Y = 2, BIG = 3 }
var _boulder_foot = [
	[[0, 0]],
	[[0, 0], [1, 0]],
	[[0, 0], [0, 1]],
	[[0, 0], [1, 0], [0, 1], [1, 1]],
];

global.iso_h = array_length(_layout);
global.iso_w = string_length(_layout[0]);

global.iso_origin_x = room_width / 2;
global.iso_origin_y = ISO_TILE_H * 3;

global.iso_floor = array_create(global.iso_w);
global.iso_hp = array_create(global.iso_w);
global.iso_prop = array_create(global.iso_w);
global.iso_fall = array_create(global.iso_w);
global.iso_burn = array_create(global.iso_w);
global.iso_solid = array_create(global.iso_w);
for (var _gx = 0; _gx < global.iso_w; _gx++) {
	global.iso_floor[_gx] = array_create(global.iso_h, -1);
	global.iso_solid[_gx] = array_create(global.iso_h, false);
	global.iso_hp[_gx] = array_create(global.iso_h, ISO_TILE_HP);
	global.iso_prop[_gx] = array_create(global.iso_h, noone);
	global.iso_fall[_gx] = array_create(global.iso_h, -1);
	global.iso_burn[_gx] = array_create(global.iso_h, 0);
}
global.iso_falling = [];
global.shake = 0;

var _player_gx = floor(global.iso_w / 2);
var _player_gy = floor(global.iso_h / 2);
var _dummy_gx = -1, _dummy_gy = -1;
var _dummy2_gx = -1, _dummy2_gy = -1;

for (var _gy = 0; _gy < global.iso_h; _gy++) {
	var _row = _layout[_gy];
	for (var _gx = 0; _gx < global.iso_w; _gx++) {
		var _c = string_char_at(_row, _gx + 1);
		var _tree = -1;
		var _boulder = -1;
		switch (_c) {
			case ".": global.iso_floor[_gx][_gy] = ISO_TILE.GRASS; break;
			case "T": global.iso_floor[_gx][_gy] = ISO_TILE.GRASS; _tree = ISO_TREE.OAK; break;
			case "Y": global.iso_floor[_gx][_gy] = ISO_TILE.GRASS; _tree = ISO_TREE.PINE; break;
			case "B": global.iso_floor[_gx][_gy] = ISO_TILE.GRASS; _boulder = ISO_BOULDER.SMALL; break;
			case "H": global.iso_floor[_gx][_gy] = ISO_TILE.GRASS; _boulder = ISO_BOULDER.LONG_X; break;
			case "V": global.iso_floor[_gx][_gy] = ISO_TILE.GRASS; _boulder = ISO_BOULDER.LONG_Y; break;
			case "O": global.iso_floor[_gx][_gy] = ISO_TILE.GRASS; _boulder = ISO_BOULDER.BIG; break;
			case "E":
				global.iso_floor[_gx][_gy] = ISO_TILE.GRASS;
				_dummy2_gx = _gx;
				_dummy2_gy = _gy;
				break;
			case "D":
				global.iso_floor[_gx][_gy] = ISO_TILE.GRASS;
				_dummy_gx = _gx;
				_dummy_gy = _gy;
				break;
			case "P":
				global.iso_floor[_gx][_gy] = ISO_TILE.GRASS;
				_player_gx = _gx;
				_player_gy = _gy;
				break;
		}
		if (_tree != -1) {
			global.iso_solid[_gx][_gy] = true;
			global.iso_prop[_gx][_gy] = instance_create_depth(iso_to_screen_x(_gx, _gy), iso_to_screen_y(_gx, _gy), iso_depth(_gx, _gy), oIsoBlock,
				{ gx: _gx, gy: _gy, cells: [[_gx, _gy]], image_index: _tree, image_speed: 0 });
		}
		if (_boulder != -1) {
			// Block every tile it covers, and anchor it on the front-most one for depth.
			var _foot = _boulder_foot[_boulder];
			var _fx = _gx, _fy = _gy;
			var _cells = [];
			for (var _i = 0; _i < array_length(_foot); _i++) {
				var _tx = _gx + _foot[_i][0], _ty = _gy + _foot[_i][1];
				if (!iso_in_bounds(_tx, _ty)) continue;
				global.iso_solid[_tx][_ty] = true;
				array_push(_cells, [_tx, _ty]);
				_fx = max(_fx, _tx);
				_fy = max(_fy, _ty);
			}
			var _rock = instance_create_depth(iso_to_screen_x(_fx, _fy), iso_to_screen_y(_fx, _fy), iso_depth(_fx, _fy), oIsoBlock,
				{ gx: _fx, gy: _fy, cells: _cells, sprite_index: sIsoBoulder, image_index: _boulder, image_speed: 0 });
			for (var _i = 0; _i < array_length(_cells); _i++) global.iso_prop[_cells[_i][0]][_cells[_i][1]] = _rock;
		}
	}
}

// How many rock chunks hang under each tile (see iso_build_under in scr_iso).
iso_build_under();

// Pixel clouds drift past below and around the island, in three layers (see iso_make_clouds).
clouds = iso_make_clouds();

// Joined a LAN match: every player comes from the host's snapshots instead (see scr_iso).
if (!global.net_client_match) instance_create_depth(0, 0, 0, oIsoPlayer, { gx: _player_gx, gy: _player_gy });

// Practice dummy: the walkable tile nearest to 3 tiles right of the player on screen.
var _dum_x = _player_gx, _dum_y = _player_gy, _dum_d = infinity;
for (var _gx = 0; _gx < global.iso_w; _gx++) {
	for (var _gy = 0; _gy < global.iso_h; _gy++) {
		if (!iso_walkable(_gx, _gy) || (_gx == _player_gx && _gy == _player_gy)) continue;
		var _d = point_distance(_gx, _gy, _player_gx + 2, _player_gy - 2);
		if (_d < _dum_d) { _dum_d = _d; _dum_x = _gx; _dum_y = _gy; }
	}
}
if (_dummy_gx >= 0) { _dum_x = _dummy_gx; _dum_y = _dummy_gy; }
// No dummies at the start for now: F1 spawns one (see Step).
//instance_create_depth(0, 0, 0, oIsoDummy, { gx: _dum_x, gy: _dum_y });

// Second dummy: its own spot on random islands, otherwise the free tile nearest to up-left of the player.
var _dum2_x = _dummy2_gx, _dum2_y = _dummy2_gy;
if (_dum2_x < 0) {
	_dum2_x = _player_gx; _dum2_y = _player_gy;
	var _dum2_d = infinity;
	for (var _gx = 0; _gx < global.iso_w; _gx++) {
		for (var _gy = 0; _gy < global.iso_h; _gy++) {
			if (!iso_walkable(_gx, _gy) || (_gx == _player_gx && _gy == _player_gy) || (_gx == _dum_x && _gy == _dum_y)) continue;
			var _d = point_distance(_gx, _gy, _player_gx - 2, _player_gy - 2);
			if (_d < _dum2_d) { _dum2_d = _d; _dum2_x = _gx; _dum2_y = _gy; }
		}
	}
}
//instance_create_depth(0, 0, 0, oIsoDummy, { gx: _dum2_x, gy: _dum2_y });
instance_create_depth(0, 0, 0, oIsoCamera);

// Pick a build before the match starts. Joined over LAN, the host's match is already on.
if (global.net_client_match) {
	global.menu_open = false;
	global.net_client_ready = true;
} else {
	instance_create_depth(0, 0, -10000, oIsoMenu);
}

hover_gx = -1;
hover_gy = -1;
had_focus = true;   // the window had focus last frame (see Step)
drops_reset();      // no sky drops left over from the last match (see Sky drops in scr_iso)
// The game's own cursor: a little cloud spirit with a gold star on its antenna (sCursor).
// It aims with the middle of its face.
cursor_sprite = sCursor;
window_set_cursor(cr_none);
