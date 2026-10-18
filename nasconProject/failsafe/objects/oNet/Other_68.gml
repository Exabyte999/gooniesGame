// Async - Networking: connections, disconnections and incoming messages.
var _type = async_load[? "type"];
var _id = async_load[? "id"];
switch (_type) {
	case network_type_connect:
		if (role == "host" && _id == server) net_host_on_connect(async_load[? "socket"]);
		break;

	case network_type_disconnect:
		if (role == "host" && _id == server) net_host_on_disconnect(async_load[? "socket"]);
		break;

	case network_type_non_blocking_connect:
		if (_id == sock) {
			connecting = false;
			if (async_load[? "succeeded"]) {
				last_heard = current_time;
				global.net_status = "JOINING...";
			} else {
				net_drop("COULDN'T CONNECT");
			}
		}
		break;

	case network_type_data:
		var _msg = net_read(async_load[? "buffer"]);
		if (is_undefined(_msg) || !is_struct(_msg)) break;
		if (_id == udp_listen) {
			net_on_presence(_msg, async_load[? "ip"]);
		} else if (role == "host") {
			net_host_on_data(_id, _msg);
		} else if (role == "client" && _id == sock) {
			last_heard = current_time;
			net_client_on_data(_msg);
		}
		break;
}
