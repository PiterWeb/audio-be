# AudioBE

This software works like a spotify proxy.
The server runing on Linux (with Spotify open) sends the audio (32 bit PCM) to the Android client using plain TCP. The android client also has simple controls: prev/next song, play/pause

The server is made using the Odin programming language with:
- vendor:miniaudio to capture the audio of the Linux desktop
- odin-dbus to communicate with spotify

The client can be found at [github.com/PiterWeb/audio-be-android](https://github.com/PiterWeb/audio-be-android)
