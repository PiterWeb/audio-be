package main

import "core:strings"
import dbus "odin-dbus"
import "core:fmt"

@(private="file")
base_service: string : "org.mpris.MediaPlayer2"
@(private="file")
object_path: cstring : "/org/mpris/MediaPlayer2"
@(private="file")
music_player_interface: cstring: "org.mpris.MediaPlayer2.Player"

@(private="file")
player_method_play_pause: cstring : "PlayPause"
@(private="file")
player_method_previous: cstring: "Previous"
@(private="file")
player_method_next: cstring: "Next"

apps_controller :: [2]string{"spotify", "vlc"}

PlayerController :: struct {
	conn: ^dbus.Connection,
	service: cstring,
}

init_player_controller :: proc(app: string) -> PlayerController {
	dbus_err: dbus.Error
	dbus.error_init(&dbus_err)

	conn := dbus.bus_get(.SESSION, &dbus_err)
	if dbus.error_is_set(&dbus_err) {
		err_msg := string(dbus_err.message)
		dbus.error_free(&dbus_err)
		fmt.panicf("Dbus Connection Error (%s)\n", err_msg)
	}

	service_string, err := strings.concatenate([]string{base_service,".", app})

	if err != nil {
		return PlayerController{
			conn = conn, service = cstring(base_service + ".spotify")
		}
	}

	if service, err := strings.clone_to_cstring(service_string); err == nil {
		return  PlayerController{conn, service}
	}
	
	return PlayerController{
		conn = conn, service = cstring(base_service + ".spotify")
	}

}

player_play_pause :: proc (controller: PlayerController) {
	play_pause_msg := dbus.message_new_method_call(controller.service, object_path, music_player_interface, player_method_play_pause)
	dbus.connection_send(controller.conn, play_pause_msg, nil)
}

player_next :: proc (controller: PlayerController) {
	play_pause_msg := dbus.message_new_method_call(controller.service, object_path, music_player_interface, player_method_next)
	dbus.connection_send(controller.conn, play_pause_msg, nil)
}

player_prev :: proc (controller: PlayerController) {
	play_pause_msg := dbus.message_new_method_call(controller.service, object_path, music_player_interface, player_method_previous)
	dbus.connection_send(controller.conn, play_pause_msg, nil)
}

