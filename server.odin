package main

import "core:sync"
import "core:fmt"
import "core:net"
import "core:thread"
import "core:container/queue"

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

ClientType :: distinct u8
client_stream :: ClientType(0)
client_actions :: ClientType(1)

MsgType :: distinct u8
msg_prev :: MsgType(0)
msg_play_pause :: MsgType(1)
msg_next :: MsgType(2)

@(private="file")
handle_client :: proc(controller: PlayerController, sock: net.TCP_Socket, audioQueue: ^AudioQueue) {
	defer net.close(sock)

	buffer: [1]u8
	bytes_recv, err_recv := net.recv_tcp(sock, buffer[:])

	if err_recv != nil {
		return
	}

	if bytes_recv == 0 {
		return
	}

	client_type := ClientType(buffer[0])

	switch client_type {
	case client_stream:
		fmt.printfln("Stream client")
		stream_audio_client(sock, audioQueue)
	case client_actions:
		fmt.printfln("Actions client")
		for {
			bytes_recv, err_recv := net.recv_tcp(sock, buffer[:])

			if err_recv != nil {
				break
			}

			if bytes_recv == 0 {
				break
			}
			
			msg := MsgType(buffer[0])

			switch msg {
			case msg_prev:
				player_prev(controller)
			case msg_play_pause:
				player_play_pause(controller)
			case msg_next:
				player_next(controller)
			}
		}
	}
}

@(private="file")
stream_audio_client :: proc(sock: net.TCP_Socket, audioQueue: ^AudioQueue) {
	buffer: [64]u8 // Every frame is 24 bits (3 bytes) so the buffer must be len(buffer) % 3 = 0
	bufferIndex := 0

	if sync.rw_mutex_guard(&audioQueue.mutex) {
		queue.clear(&audioQueue.queue)
	}
	
	for {
		if sync.rw_mutex_guard(&audioQueue.mutex) {

			el, ok := queue.pop_front_safe(&audioQueue.queue)

			if !ok {
				continue
			}

			buffer[bufferIndex] = el
			bufferIndex += 1

			if bufferIndex >= len(buffer) {
				bytes_sent, err_send := net.send_tcp(sock, buffer[:])
				if err_send != nil {
					return
				}
				bufferIndex = 0
			}
		}
	}	
}

tcp_server :: proc(controller: PlayerController, audioQueue: ^AudioQueue, ip: string, port: int) {
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

	defer net.close(sock)
	
	fmt.printfln("Listening on TCP: %s", net.endpoint_to_string(endpoint))
	for {
		cli, _, err_accept := net.accept_tcp(sock)
		if err_accept != nil {
			fmt.println("Failed to accept TCP connection")
			continue
		}
		thread.create_and_start_with_poly_data3(controller, cli, audioQueue, handle_client)
	}
	fmt.println("Closed socket")
}