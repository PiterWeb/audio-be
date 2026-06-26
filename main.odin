package main

import "core:sync"
import "core:c"
import "core:thread"
import "core:strconv"
import "core:strings"
import "core:bufio"
import "core:io"
import "core:fmt"
import ma "vendor:miniaudio"
import "core:os"
import "base:runtime"
import "core:container/queue"
import dbus "odin-dbus"

AudioQueue :: struct {
	queue: queue.Queue(u8),
	mutex: sync.RW_Mutex
}

main :: proc() {

	dbus_conn := init_dbus()
	defer dbus.connection_unref(dbus_conn)

	entry_group_mdns := announce_mdns(dbus_conn)
	
	ctx := ma.context_type{}
	result := ma.context_init(nil, 0, nil, &ctx)
	if result != ma.result.SUCCESS {
		fmt.panicf("Ctx init failed: %s\n", result)
	}

	pCaptureInfos: [^]ma.device_info
	captureCount: u32

	result = ma.context_get_devices(&ctx, nil, nil, &pCaptureInfos, &captureCount)
	if result != ma.result.SUCCESS {
		fmt.panicf("Get devices failed: %s\n", result)
	}

	for iDevice := u32(0); iDevice < captureCount; iDevice += 1 {
	    fmt.printfln("Capture %d - %s", iDevice, pCaptureInfos[iDevice].name);
	}

	captureDeviceId := u64(0)

	fmt.println("")

	stdin := os.to_stream(os.stdin)
	defer io.close(stdin)
	
	r : bufio.Reader
	bufio.reader_init(&r, stdin)
	
	for {
		fmt.printfln("Type the number of the device you want to capture (ex: 0):")
		
		bytes, err := bufio.reader_read_slice(&r, '\n')
		assert(err == .None)

		line := strings.trim_space(string(bytes))
		if id, ok := strconv.parse_u64(line); ok {
			if id > u64(captureCount) - 1 {
				continue
			}
			captureDeviceId = id
			break
		}
		
	}

	fmt.printfln("Selected device: %d - %s", captureDeviceId, pCaptureInfos[captureDeviceId].name)
	
	encoderConfig := ma.encoder_config{}
	encoder := ma.encoder{}

	config := ma.device_config_init(ma.device_type.capture)
	config.capture.format = ma.format.s24
	config.capture.channels = 2
	config.capture.pDeviceID = &pCaptureInfos[captureDeviceId].id
	config.sampleRate = 44100
	config.dataCallback = device_capture_proc
	
	encoderConfig = ma.encoder_config_init(ma.encoding_format.wav, config.capture.format, config.capture.channels, config.sampleRate)

	audioQueue := AudioQueue{}
	queue.init(&audioQueue.queue, 1024 * 1024 * 5) // 5 MB Capacity
	
	result = ma.encoder_init(on_write, on_seek, &audioQueue, &encoderConfig, &encoder)
	
	if result != ma.result.SUCCESS {
		fmt.panicf("Failed to initialize output file\n")
	}

	defer ma.encoder_uninit(&encoder)
	
	config.pUserData = &encoder
	
	device := ma.device{}
	result = ma.device_init(&ctx, &config, &device)
	if result != ma.result.SUCCESS {
		fmt.panicf("Device init failed: %s\n", result)
	}

	ma.device_start(&device)
	defer ma.device_uninit(&device) 

	tcp_address :: "0.0.0.0"
	tcp_port :: 8080
	
	tcp_server_th := thread.create_and_start_with_poly_data4(dbus_conn, &audioQueue, tcp_address, tcp_port, tcp_server)
	defer thread.terminate(tcp_server_th, 0)
	
	for {
		fmt.println("Type \"exit\" to close the program:")
		
		bytes, err := bufio.reader_read_slice(&r, '\n')
		assert(err == .None)

		line := strings.trim_space(string(bytes))
		line = strings.to_lower(line)

		if line == "exit" {
			break
		} else if line == "next" {
			spotify_next(dbus_conn)
		} else if line == "prev" {
			spotify_prev(dbus_conn)
		} else if line == "play/pause" {
			spotify_play_pause(dbus_conn)
		}
	}
}

device_capture_proc :: proc "c" (pDevice: ^ma.device, _, pInput: rawptr, frameCount: u32) {
	ma.encoder_write_pcm_frames((^ma.encoder)(pDevice.pUserData), pInput, u64(frameCount), nil)
}

on_write :: proc "c" (pEncoder: ^ma.encoder, pBufferIn: rawptr, bytesToWrite: c.size_t, pBytesWritten: ^c.size_t) -> ma.result {
	audioQueue := cast(^AudioQueue)(pEncoder.pUserData)
	bufferIn := cast([^]u8)(pBufferIn)
	
	context = runtime.default_context()

	if sync.rw_mutex_guard(&audioQueue.mutex) {

		if queue.space(audioQueue.queue) < int(bytesToWrite) {
			queue.consume_front(&audioQueue.queue, int(bytesToWrite))
			_, err := queue.push_back_elems(&audioQueue.queue, ..bufferIn[:bytesToWrite])

			if err != nil {
				return ma.result.ERROR
			}
		
		} else {
			_, err := queue.push_back_elems(&audioQueue.queue, ..bufferIn[:bytesToWrite])
		
			if err != nil {
				return ma.result.ERROR
			}	
		}

		// fmt.printfln("Audioqueue size: %d", audioQueue.queue.len)
	}
	
	pBytesWritten^ = bytesToWrite

	return ma.result.SUCCESS
}

on_seek :: proc "c" (pEncoder: ^ma.encoder, offset: i64, origin: ma.seek_origin) -> ma.result {
	return ma.result.SUCCESS
}