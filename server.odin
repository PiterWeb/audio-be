package main

import "core:sync"
import "core:fmt"
import "core:net"
import "core:thread"
import "core:container/queue"
import dbus "odin-dbus"

@(private="file")
is_ctrl_d :: proc(bytes: []u8) -> bool {
	return len(bytes) == 1 && bytes[0] == 4
}

@(private="file")
is_empty :: proc(bytes: []u8) -> bool {
	return(
		(len(bytes) == 2 && bytes[0] == '\r' && bytes[1] == '\n') ||
		(len(bytes) == 1 && bytes[0] == '\n') \
	)
}

@(private="file")
is_telnet_ctrl_c :: proc(bytes: []u8) -> bool {
	return(
		(len(bytes) == 3 && bytes[0] == 255 && bytes[1] == 251 && bytes[2] == 6) ||
		(len(bytes) == 5 &&
				bytes[0] == 255 &&
				bytes[1] == 244 &&
				bytes[2] == 255 &&
				bytes[3] == 253 &&
				bytes[4] == 6) \
	)
}

@(private="file")
handle_client :: proc(dbus_conn: ^dbus.Connection, sock: net.TCP_Socket, audioQueue: ^AudioQueue) {
	defer net.close(sock)

	th_stream_audio := thread.create_and_start_with_poly_data2(sock, audioQueue, stream_audio_client)
	defer thread.terminate(th_stream_audio, 0)

	buffer: [1]u8
	
	for {
		bytes_recv, err_recv := net.recv_tcp(sock, buffer[:])

		if err_recv != nil {
			break
		}

		if bytes_recv == 0 {
			break
		}
		
		msg := buffer[0]

		if msg == 0 {
			spotify_prev(dbus_conn)			
		} else if msg == 1 {
			spotify_play_pause(dbus_conn)
		} else if msg == 2 {
			spotify_next(dbus_conn)
		}
		
	}
	
}

@(private="file")
stream_audio_client :: proc(sock: net.TCP_Socket, audioQueue: ^AudioQueue) {
	buffer: [96]u8 // Every frame is 24 bits (3 bytes) so the buffer must be len(buffer) % 3 = 0
	bufferIndex := 0

	for {
		if sync.rw_mutex_guard(&audioQueue.mutex) {

			el, ok := queue.pop_front_safe(&audioQueue.queue)

			if !ok {
				continue
			}

			buffer[bufferIndex] = el
			bufferIndex += 1

			if bufferIndex >=len(buffer) {
				bytes_sent, err_send := net.send_tcp(sock, buffer[:])
				if err_send != nil {
					return
				}
				bufferIndex = 0
			}
		}
	}	
}

tcp_server :: proc(dbus_conn: ^dbus.Connection, audioQueue: ^AudioQueue, ip: string, port: int) {
	local_addr, ok := net.parse_ip4_address(ip)
	if !ok {
		fmt.println("Failed to parse IP address")
		return
	}
	endpoint := net.Endpoint {
		address = local_addr,
		port    = port,
	}
	sock, err := net.listen_tcp(endpoint)
	if err != nil {
		fmt.println("Failed to listen on TCP")
		return
	}
	fmt.printfln("Listening on TCP: %s", net.endpoint_to_string(endpoint))
	for {
		cli, _, err_accept := net.accept_tcp(sock)
		if err_accept != nil {
			fmt.println("Failed to accept TCP connection")
			continue
		}
		thread.create_and_start_with_poly_data3(dbus_conn, cli, audioQueue, handle_client)
	}
	net.close(sock)
	fmt.println("Closed socket")
}