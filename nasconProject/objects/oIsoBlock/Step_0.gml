// Drop away when the ground under it crumbles.
if (falling) {
	fall_vy += 0.35;
	y += fall_vy;
	image_alpha -= 0.015;
	if (image_alpha <= 0) instance_destroy();
	exit;
}

// Boulder shake fades out.
shake = (shake > 0.3) ? shake * 0.8 : 0;

// Tree sway is a spring back to upright. A broken tree tips over instead.
if (broken && !is_boulder) {
	// Lean over a little (up to 25 degrees) while it fades.
	sway_v = clamp(sway_v + sign(sway == 0 ? 1 : sway) * 0.15, -1.5, 1.5);
	sway = clamp(sway + sway_v, -25, 25);
} else {
	sway_v += -sway * 0.12;
	sway_v *= 0.86;
	sway += sway_v;
}

// Stone chips bounce, leaves flutter down.
for (var _i = array_length(parts) - 1; _i >= 0; _i--) {
	var _p = parts[_i];
	if (_p.leaf) {
		_p.t += 0.12;
		_p.px += _p.vx + sin(_p.t) * 0.5;
		_p.py = min(_p.ground, _p.py + _p.vy);
	} else {
		_p.vy += 0.3;
		_p.px += _p.vx;
		_p.py += _p.vy;
		if (_p.py > _p.ground) { _p.py = _p.ground; _p.vy *= -0.3; _p.vx *= 0.6; }
	}
	_p.life--;
	if (_p.life <= 0) array_delete(parts, _i, 1);
}

if (broken) {
	image_alpha -= is_boulder ? 0.08 : 0.03;
	if (image_alpha <= 0 && array_length(parts) == 0) instance_destroy();
}
