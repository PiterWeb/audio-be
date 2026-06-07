package main

import "core:thread"
import "core:strconv"
import "core:strings"
import "core:bufio"
import "core:io"
import "core:fmt"
import ma "vendor:miniaudio"
import "core:os"

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

	fmt.printfln("")

	stdin := os.to_stream(os.stdin)
	defer io.close(stdin)
	
	r : bufio.Reader
	bufio.reader_init(&r, stdin)
	
	for {
		fmt.println("Type the number of the device you want to capture (ex: 0):")
		
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

	fmt.printfln("")
	fmt.printf("Selected device: %d - %s", captureDeviceId, pCaptureInfos[captureDeviceId].name)
	fmt.printfln("")
	
	encoderConfig := ma.encoder_config{}
	encoder := ma.encoder{}

	config := ma.device_config_init(ma.device_type.capture)
	config.capture.format = ma.format.f32
	config.capture.channels = 2
	config.capture.pDeviceID = &pCaptureInfos[captureDeviceId].id
	config.sampleRate = 44100
	config.dataCallback = device_capture_proc
	
	encoderConfig = ma.encoder_config_init(ma.encoding_format.wav, config.capture.format, config.capture.channels, config.sampleRate)

	result = ma.encoder_init_file("test.wav", &encoderConfig, &encoder)

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