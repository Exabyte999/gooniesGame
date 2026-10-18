// Begin Step: fill this frame's input record. Step only ever reads the record.
// Your player reads the keyboard and mouse (and, joined over LAN, sends it to the host).
// On the host, a joiner's player takes what their game sent (see LAN in scr_iso).
if (is_local) {
	input_read_local(input);
	if (net_puppet) net_client_send_input(input);
} else if (!net_puppet) {
	input.move_x = net_in.move_x;
	input.move_y = net_in.move_y;
	input.aim_gx = net_in.aim_gx;
	input.aim_gy = net_in.aim_gy;
	input.whip = net_in.whip;
	input.ability = net_in.ability;
	input.pause = false;
	net_in.whip = false;
	net_in.ability = false;
}
