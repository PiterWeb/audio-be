package main

import "core:strings"
import "core:fmt"
import dbus "odin-dbus"

@(private="file")
avahi_service: cstring : "org.freedesktop.Avahi"
@(private="file")
object_path: cstring : "/"
@(private="file")
avahi_server_interface: cstring: avahi_service + ".Server"
@(private="file")
avahi_entry_group_interface: cstring: avahi_service + ".EntryGroup"


@(private="file")
avahi_method_entry_group_new: cstring : "EntryGroupNew"
@(private="file")
avahi_method_free: cstring : "Free"
@(private="file")
avahi_method_add_service: cstring : "AddService"
@(private="file")
avahi_method_commit_service: cstring : "Commit"

MDNSController :: struct {
	conn: ^dbus.Connection,
	entry_group_path: cstring,
}

announce_mdns :: proc () -> MDNSController {

	dbus_err: dbus.Error
	dbus.error_init(&dbus_err)
	
	conn := dbus.bus_get(.SYSTEM, &dbus_err)
	if dbus.error_is_set(&dbus_err) {
		err_msg := strings.clone_from_cstring(dbus_err.message)
		dbus.error_free(&dbus_err)
		fmt.panicf("Dbus Connection Error (%s)\n", err_msg)
	}
	
	msgNewEntryGroup := dbus.message_new_method_call(avahi_service, object_path, avahi_server_interface, avahi_method_entry_group_new)

	defer dbus.message_unref(msgNewEntryGroup)
	
	replyNewEntryGroup := dbus.connection_send_with_reply_and_block(conn, msgNewEntryGroup, dbus.TIMEOUT_USE_DEFAULT, &dbus_err)

	if dbus.error_is_set(&dbus_err) {
		err_msg := strings.clone_from_cstring(dbus_err.message)
		dbus.error_free(&dbus_err)
		fmt.panicf("Dbus Error (%s)\n", err_msg)
	}

	defer dbus.message_unref(replyNewEntryGroup)

	entry_group_path: cstring
	
	if !dbus.message_get_args(replyNewEntryGroup, &dbus_err, dbus.Type.OBJECT_PATH, &entry_group_path, dbus.Type.INVALID) || dbus.error_is_set(&dbus_err) {
		err_msg := strings.clone_from_cstring(dbus_err.message)
		dbus.error_free(&dbus_err)
		fmt.panicf("Dbus Error (%s)\n", err_msg)
	}
	
	fmt.printfln("Entry group: %s", entry_group_path)

	msgAddService := dbus.message_new_method_call(avahi_service, entry_group_path, avahi_entry_group_interface, avahi_method_add_service)

	defer dbus.message_unref(msgAddService)
	
	interface := i32(-1)
	protocol := i32(-1)
	flags := u32(256) // use multicast DNS
	service_name: cstring = "AudioBE"
	service_type: cstring = "_ws._tcp"
	domain: cstring = ""
	host: cstring = ""
	port := u16(8080)
	
	dbus.message_append_args(
		msgAddService,
		dbus.Type.INT32, &interface,
		dbus.Type.INT32, &protocol,
		dbus.Type.UINT32, &flags,
		dbus.Type.STRING, &service_name,
		dbus.Type.STRING, &service_type,
		dbus.Type.STRING, &domain,
		dbus.Type.STRING, &host,
		dbus.Type.UINT16, &port,
		dbus.Type.INVALID
	)

	iter, sub: dbus.MessageIter
	
	dbus.message_iter_init_append(msgAddService, &iter)
	dbus.message_iter_open_container(&iter, dbus.Type.ARRAY, "ay", &sub)
	dbus.message_iter_close_container(&iter, &sub)
	
	dbus.connection_send_with_reply_and_block(conn, msgAddService, dbus.TIMEOUT_USE_DEFAULT, &dbus_err)
	
	if dbus.error_is_set(&dbus_err) {
		err_msg := strings.clone_from_cstring(dbus_err.message)
		dbus.error_free(&dbus_err)
		fmt.panicf("Dbus Error (%s)\n", err_msg)
	}

	msgCommit := dbus.message_new_method_call(avahi_service, entry_group_path, avahi_entry_group_interface, avahi_method_commit_service)
	
	dbus.connection_send_with_reply_and_block(conn, msgCommit,  dbus.TIMEOUT_USE_DEFAULT, &dbus_err)

	if dbus.error_is_set(&dbus_err) {
		err_msg := strings.clone_from_cstring(dbus_err.message)
		dbus.error_free(&dbus_err)
		fmt.panicf("Dbus Error (%s)\n", err_msg)
	}
	
	return MDNSController{
		conn, entry_group_path 
	}
}

free_mdns :: proc (controller: MDNSController) {

	dbus_err: dbus.Error
	dbus.error_init(&dbus_err)
	
	defer dbus.connection_unref(controller.conn)
	
	msg := dbus.message_new_method_call(avahi_service, controller.entry_group_path, avahi_entry_group_interface, avahi_method_free)
	dbus.connection_send_with_reply_and_block(controller.conn, msg, dbus.TIMEOUT_USE_DEFAULT, &dbus_err)

	if dbus.error_is_set(&dbus_err) {
		err_msg := strings.clone_from_cstring(dbus_err.message)
		dbus.error_free(&dbus_err)
		fmt.panicf("Dbus Error (%s)\n", err_msg)
	}
}