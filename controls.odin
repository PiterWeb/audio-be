package main

import dbus "odin-dbus"
import "core:fmt"

@(private="file")
spotify_service: cstring : "org.mpris.MediaPlayer2.spotify"
@(private="file")
object_path: cstring : "/org/mpris/MediaPlayer2"
@(private="file")
spotify_interface: cstring: "org.mpris.MediaPlayer2.Player"

@(private="file")
spotify_method_play_pause: cstring : "PlayPause"
@(private="file")
spotify_method_previous: cstring: "Previous"
@(private="file")
spotify_method_next: cstring: "Next"

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
	msg := dbus.message_new_method_call(spotify_service, object_path, spotify_interface, spotify_method_play_pause)
	dbus.connection_send(conn, msg, nil)
}

spotify_next :: proc (conn: ^dbus.Connection) {
	msg := dbus.message_new_method_call(spotify_service, object_path, spotify_interface, spotify_method_next)
	dbus.connection_send(conn, msg, nil)
}

spotify_prev :: proc (conn: ^dbus.Connection) {
	msg := dbus.message_new_method_call(spotify_service, object_path, spotify_interface, spotify_method_previous)
	dbus.connection_send(conn, msg, nil)
}