// Begin Step: Steam first (its callbacks and packets), then, joined a match, put the
// host's newest snapshot on the island before anything moves.
net_steam_pump();
if (role == "client") net_client_apply();
