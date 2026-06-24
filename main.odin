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

AudioQueue :: struct {
	queue: queue.Queue(u8),
	mutex: sync.RW_Mutex
}

main :: proc() {

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
	    fmt.printf("Capture %d - %s\n", iDevice, pCaptureInfos[iDevice].name);
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
	config.capture.format = ma.format.u8
	config.capture.channels = 2
	config.capture.pDeviceID = &pCaptureInfos[captureDeviceId].id
	config.sampleRate = 44100
	config.dataCallback = device_capture_proc
	
	encoderConfig = ma.encoder_config_init(ma.encoding_format.wav, config.capture.format, config.capture.channels, config.sampleRate)
	
	// result = ma.encoder_init_file("test.wav", &encoderConfig, &encoder)

	audioQueue := AudioQueue{}
	queue.init(&audioQueue.queue)
	
	result = ma.encoder_init(on_write, on_seek, &audioQueue, &encoderConfig, &encoder)

	defer {
		sync.rw_mutex_shared_guard(&audioQueue.mutex)
		// audioStream := io.Reader{data = &audioQueue.queue.data}
		// err := os.write_entire_file_from_bytes("test.wav", audioQueue.queue.data[:])
		// assert(err == nil)
	}
	
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

	tcp_server_th := thread.create_and_start_with_poly_data2("0.0.0.0", 8080, tcp_server)

	defer thread.terminate(tcp_server_th, 0)
	
	for {
		fmt.println("Type \"exit\" to close the program:")
		
		bytes, err := bufio.reader_read_slice(&r, '\n')
		assert(err == .None)

		line := strings.trim_space(string(bytes))
		line = strings.to_lower(line)

		if line == "exit" {
			break
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
		
		// for i in 0..<bytesToWrite {
		// 	_, err := queue.push_back(&audioQueue.queue, bufferIn[i])
		
		// 	if err != nil {
		// 		fmt.panicf("Error append: %s\n", err)
		// 	}	
		// }
		
		_, err := queue.push_back_elems(&audioQueue.queue, ..bufferIn[:bytesToWrite])
	
		if err != nil {
			fmt.panicf("Error append: %s\n", err)
		}	

		fmt.printfln("Audioqueue size: %d", audioQueue.queue.len)
	}
	
	pBytesWritten^ = bytesToWrite

	return ma.result.SUCCESS
}

on_seek :: proc "c" (pEncoder: ^ma.encoder, offset: i64, origin: ma.seek_origin) -> ma.result {
	return ma.result.SUCCESS
}

// Playback

// package main

// import "core:fmt"
// import ma "vendor:miniaudio"

// main :: proc() {

// 	engine := ma.engine{}
// 	engineConfig := ma.engine_config_init()
	
// 	result := ma.engine_init(&engineConfig, &engine)

// 	if result != ma.result.SUCCESS {
// 		fmt.panicf("Error init engine: %s", result)
// 	}

// 	ma.engine_play_sound(&engine, "test.mp3", nil)

// 	for {}
// }