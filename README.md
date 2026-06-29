# AudioBE

### This software works like a spotify (or VLC) proxy.
 
The server runing on Linux (with spotify/vlc) sends the audio (32 bit PCM) to the Android client using plain TCP.<br>
The android client also has simple controls: prev/next song, play/pause. The server discovery is made using DNS-SD (DNS Service Discovery)

The server is made using the Odin programming language with:
- vendor:miniaudio to capture the audio of the Linux desktop
- odin-dbus to communicate with: spotify and avahi

The client can be found at [github.com/PiterWeb/audio-be-android](https://github.com/PiterWeb/audio-be-android)

## How to build
(You can only compile for 64-bit Linux)


You will need to clone the repo with submodules

```sh
git clone --recurse-submodules https://github.com/PiterWeb/audio-be.git
```
Then you compile with the [Odin](https://odin-lang.org/) compiler
```sh
odin build .
```
