// Hosting, finding games and the lobby connection, over LAN or Steam (global.net_mode).
// Persistent, so a connection survives the room restarting between matches, and Steam
// keeps running for invites. Only one ever exists (see net_ensure).
role = "none";       // "host", "client" or "none"
server = -1;         // host: TCP server players connect to
udp_send = -1;       // host: socket for "a game is hosted here" broadcasts
udp_listen = -1;     // joining: socket that hears those broadcasts
sock = -1;           // client: connection to the host (its Steam ID online)
connecting = false;  // client: still waiting for the connection to open
games = [];          // joining: games found on the network { ip, players, max, in_match, seen }
local_host = false;  // joining on LAN: another copy of the game on this PC is hosting (see net_check_local_host)
last_heard = 0;      // client: when the host last sent anything (current_time)
tick = 0;
steam_lobby = 0;     // online: the Steam lobby we host or joined, 0 if none
steam_games = [];    // joining online: lobbies Steam listed { lobby, host, players, in_match }
listing = false;     // joining online: waiting for Steam's lobby list
list_at = 0;         // when the list was last asked for (current_time)
browsing = false;    // the online game list is up, so it refreshes every few seconds
steam_missing = {};  // hosting online: checks in a row each player was missing from the lobby
