# Video Scripts

This repo contains various scripts I use to manage my video files.

### Scripts:

- [HandbrakeScript](./HandbrakeScript.ps1)

  - This is the main script which is based off a script by Rocketcandy ~~I can no longer find the source of (will link if I ever find it again)~~ [I found it](https://github.com/Rocketcandy/VideoFileResizer). which I've edited to use [PSEverything](https://github.com/powercode/PSEverything) and the [Everything](https://www.voidtools.com/) service to quickly gather a PowerShell object of all video files in the listed directory.
  - Once it has said list, it will use [FFprobe](./bin/ffprobe.exe) to check if the file is already HEVC encoded before proceeding to use [HandBrake](https://github.com/HandBrake/HandBrake) with either the default presets from a GUI install or [my own](./SkittlesPresets.json) presets I've packaged in this repo.
  - -DelCSV flag to recreate the ConversionsCompleted.csv
  - Usage: `.\HandbrakeScript.ps1 -Path "everything search term" (optional: -DelCSV)`
  - Example: `.\HandbrakeScript.ps1 -DelCSV -Path "<The Flash> <S01|S02|S03>"`

- [HEVCCheck](./HEVCCheck.ps1)

  - Based on the [HandbrakeScript](./HandbrakeScript.ps1), but slimmed down to not actually encode anything, it is used as a way to quickly see what needs encoding before running the main script. You could also edit it for your own needs. (-DelCSV flag to recreate the HEVCCheck.csv)
  - Usage: `.\HEVCCheck.ps1 -Path "everything search term" (optional: -DelCSV)`
  - Example: `.\HEVCCheck.ps1 -Path "<Stranger Things>|<Brooklyn Nine-Nine>"`

### Output:

- Once either [HandbrakeScript](./HandbrakeScript.ps1) or [HEVCCheck](./HEVCCheck.ps1) is ran, a CSV file will be created.
- `ConversionsCompleted.csv`
  - Contains a list of completed conversions, obviously.
- `HEVCCheck.csv`
  - Contains a list of files which have yet to be converted. Editing the loop from [line 48 in HEVCCheck](./HEVCCheck.ps1#L48), would be recommended if different results are needed.
- Both files are formatted the same. `Codec, Height, Filename, Bitrate` This makes it easier for me to see if any shows or movies are lower quality than I'd like.

### Issues:

- You tell me

### MKVTool Scripts:

- [mergeMKV](./mergeMKV.ps1)

  - Also based on the [HandbrakeScript](./HandbrakeScript.ps1) but it's usecase is for for switching default tracks in multi-sub/dual audio anime releases, fixing und language sub tracks and removing all subtitle tracks from a file.
  - However it could be used for basically anything mkvmerge can do (-MKVMergeArgs flag allows manual parsing of options to mkvmerge).
  - The -DelSubs switch is used to remove all subtitles from a file (-S flag) and can be used alongside -Audio, but is useless when mixed with -Subs.
  - The -Lang flag can be used to fix undefined subtitle tracks by forcing a language tag for all sub tracks (ja/jap/en/eng) (Generally subtitle tracks are undefined if there is only one, however YMMV)
  - This script also partially works on mp4 files, but only for the -DelSubs option
  - Usage: `.\mergeMKV.ps1 -Path "everything search term" (optional: -DelSubs, -Subs TrackName, -Audio LanguageTag -Lang LanguageTag)`
  - Example: `.\mergeMKV.ps1 -Path "Tower.of.God S01E02" -Subs Dialogue -Audio jpn -Lang ja`

- [MKVCheck](./MKVCheck.ps1)
  - A simple script like [HEVCCheck](./HEVCCheck.ps1), however it's primary usecase is to quickly list all tracks (excluding video tracks) of a video file
  - The script will list the filename, track ID, track name, track language, and track type and output them as a csv in the terminal as well as save them to MKVCheck.csv.
  - Usage: `.\MKVCheck.ps1 -Path "everything search term"`

### Output:

- [mergeMKV] Once a file is merged/muxed, the original will be deleted and the new will be renamed, if mkvmerge encounters any errors or warnings, the new file will be deleted and the original kept instead.
- [MKVCheck] Will create MKVCheck.csv and output a csv object to the terminal

### MKVTool Issues:

- You tell me

### Requirements:

- [HandBrakeGUI/CLI](https://github.com/HandBrake/HandBrake) - GUI version is optional
- [MKVToolNix](https://mkvtoolnix.download/) - Add C:\Program Files\MKVToolNix to $Path
- [Everything](https://www.voidtools.com/) - Installed as a service
- [PSEverything](https://github.com/powercode/PSEverything)
- [FFmpeg/FFprobe](https://github.com/yt-dlp/FFmpeg-Builds/releases/tag/latest) - linked is the yt-dlp builds of FFmpeg as that's what I use
- [PowerShell 5.1+](https://aka.ms/PowerShell-Release) - Personally I use pwsh 7.x

- For HandBrakeCLI and FFProbe, I'd recommend creating and adding them to a C:\bin directory and adding that to $Path
