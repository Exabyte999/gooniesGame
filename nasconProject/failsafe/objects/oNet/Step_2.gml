// End Step: hosting a match, send everyone this frame once every body has moved.
if (role == "host" && tick mod NET_SNAP_EVERY == 0) net_send_snapshot();
