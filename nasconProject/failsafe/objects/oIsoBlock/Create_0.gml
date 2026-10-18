// Trees and boulders. oIsoWorld passes in gx, gy, cells (every tile it covers),
// and sprite_index / image_index for the kind of prop.
falling = false;   // the ground under it crumbled
fall_vy = 0;

is_boulder = (sprite_index == sIsoBoulder);
// Health: trees are weak, boulders get tougher the bigger they are.
//                SMALL LONG_X LONG_Y BIG
var _boulder_hp = [6,    10,    10,    16];
max_hp = is_boulder ? _boulder_hp[floor(image_index)] : 3;
hp = max_hp;
broken = false;    // knocked down, fading away

shake = 0;         // boulders shake in pixels when hit
sway = 0;          // trees sway in degrees when hit
sway_v = 0;
parts = [];        // stone chips and leaves

// Called by the chain. _side is the direction the whip swept (-1 or 1).
take_hit = function(_dmg, _side) {
	if (broken || falling) return;
	hp -= _dmg;
	if (is_boulder) {
		shake = 4;
		repeat (7) add_stone();
	} else {
		sway_v += 4 * _side;
		repeat (7) add_leaf();
	}
	if (hp <= 0) {
		broken = true;
		game_event("prop_broken", { gx: gx, gy: gy });
		// Free the tiles it stood on.
		for (var _i = 0; _i < array_length(cells); _i++) {
			var _cx = cells[_i][0], _cy = cells[_i][1];
			if (!iso_in_bounds(_cx, _cy)) continue;
			if (global.iso_prop[_cx][_cy] == id) global.iso_prop[_cx][_cy] = noone;
			if (global.iso_floor[_cx][_cy] != -1) global.iso_solid[_cx][_cy] = false;
		}
		if (is_boulder) { shake = 7; repeat (18) add_stone(); }
		else { sway_v += 3 * _side; repeat (14) add_leaf(); }
	}
};

// Size of the rock on screen, for where chips fly from.
var _w = [20, 34, 34, 44][is_boulder ? floor(image_index) : 0];
rock_w = _w;
rock_h = is_boulder ? [18, 22, 22, 34][floor(image_index)] : 0;

add_stone = function() {
	var _g = choose(make_colour_rgb(150, 150, 158), make_colour_rgb(118, 118, 126), make_colour_rgb(176, 176, 182));
	array_push(parts, {
		px: x + random_range(-rock_w, rock_w) * 0.6, py: y - random_range(4, rock_h),
		vx: random_range(-1.6, 1.6), vy: random_range(-3.2, -1),
		ground: y + random_range(-6, 8), life: irandom_range(35, 60),
		size: choose(1, 1, 2), col: _g, leaf: false,
	});
};

add_leaf = function() {
	var _g = choose(make_colour_rgb(52, 124, 58), make_colour_rgb(40, 104, 48), make_colour_rgb(84, 150, 70));
	array_push(parts, {
		px: x + random_range(-18, 18), py: y - random_range(36, 72),
		vx: random_range(-0.6, 0.6), vy: random_range(0.3, 0.8),
		ground: y + random_range(-6, 8), life: irandom_range(50, 80),
		size: choose(1, 2), col: _g, leaf: true, t: random(100),
	});
};
