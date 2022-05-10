# Video Scripts

This repo contains various scripts I use to manage my video files.

### Scripts:
* [HandbrakeScript](./HandbrakeScript.ps1)
    * This is the main script which is based off a script I can no longer find the source of (will link if I ever find it again). which I've edited to use [PSEverything](https://github.com/powercode/PSEverything) and the [Everything](https://www.voidtools.com/) service to quickly gather a PowerShell object of all video files in the listed directory.
    * Once it has said list, it will use [FFprobe](./bin/ffprobe.exe) to check if the file is already HEVC encoded before proceeding to use [HandBrake](https://github.com/HandBrake/HandBrake) with either the default presets from a GUI install or [my own](./SkittlesPresets.json) presets I've packaged in this repo.
    * Usage: `.\HandbrakeScript.ps1 \\remote\drive\Movies\`

* [HEVCCheck](./HEVCCheck.ps1)
    * Based on the [HandbrakeScript](./HandbrakeScript.ps1), but slimmed down to not actually encode anything, it is used as a way to quickly see what needs encoding before running the main script. You could also edit it for your own needs.
    * Usage: `.\HEVCCheck.ps1 D:\TV Shows\`

### Output:
* Once either script is ran, a CSV file will be created.
* `ConversionsCompleted.csv`
    * Contains a list of completed conversions, obviously.
* `HEVCCheck.csv`
    * Contains a list of files which have yet to be converted. Editing the loop from [line 49 in HEVCCheck](./HEVCCheck.ps1#L49), would be recommended if different results are needed.
* Both files are formatted the same. `Height, Filename, Bitrate` This makes it easier for me to see if any shows or movies are lower quality than I'd like.

### Requirements:
- [HandBrakeGUI/CLI](https://github.com/HandBrake/HandBrake) - GUI version is optional
- [Everything](https://www.voidtools.com/) - Installed as a service
- [PSEverything](https://github.com/powercode/PSEverything)
- [FFprobe](https://github.com/yt-dlp/FFmpeg-Builds/releases/tag/latest) - linked is the yt-dlp builds of FFmpeg as that's what I use
- [PowerShell 5.1+](https://aka.ms/PowerShell-Release) - Personally I use pwsh 7.x

### Issues:
* You tell me
