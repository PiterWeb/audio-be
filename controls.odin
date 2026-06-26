package main

import dbus "odin-dbus"
import "core:fmt"

@(private="file")
spotify_service: cstring : "org.mpris.MediaPlayer2.spotify"
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

init_dbus :: proc() -> ^dbus.Connection {
	err: dbus.Error
	dbus.error_init(&err)

	conn := dbus.bus_get(.SESSION, &err)
	if dbus.error_is_set(&err) {
		fmt.eprintfln("Connection Error (%s)", err.message)
		dbus.error_free(&err)
	}

	return conn

}

spotify_play_pause :: proc (conn: ^dbus.Connection) {
	play_pause_msg := dbus.message_new_method_call(spotify_service, object_path, music_player_interface, player_method_play_pause)
	dbus.connection_send(conn, play_pause_msg, nil)
}

spotify_next :: proc (conn: ^dbus.Connection) {
	next_msg := dbus.message_new_method_call(spotify_service, object_path, music_player_interface, player_method_next)
	dbus.connection_send(conn, next_msg, nil)
}

spotify_prev :: proc (conn: ^dbus.Connection) {
	prev_msg := dbus.message_new_method_call(spotify_service, object_path, music_player_interface, player_method_previous)
	dbus.connection_send(conn, prev_msg, nil)
}