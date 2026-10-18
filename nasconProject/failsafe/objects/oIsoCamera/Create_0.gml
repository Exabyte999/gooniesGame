view_w = 1366;
var _rs = settings_render_size();
view_h = round(view_w * _rs[1] / _rs[0]);   // 768 at 16:9, taller on 16:10 screens
settings_apply_view();
zoom = 1;          // >1 shows more of the map
follow_speed = 0.12;
spectate_speed = 9;   // screen pixels per step when flying around after being eliminated

cam = camera_create_view(0, 0, view_w, view_h);
view_enabled = true;
view_visible[0] = true;
view_camera[0] = cam;

cam_x = instance_exists(oIsoPlayer) ? oIsoPlayer.x : room_width / 2;
cam_y = instance_exists(oIsoPlayer) ? oIsoPlayer.y : room_height / 2;
