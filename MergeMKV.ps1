Param(
    [Parameter(Mandatory = $true)] [string] $Path,
    [string] $Subs,
    [string] $Audio,
    [string] $Lang,
    [switch] $DelSubs,
    [string] $MKVMergeArgs
)

Import-Module PSEverything
if (-not(Get-Module PSEverything)) {
    Write-Host 'The Powershell module PSEverything and the Everything service are required for this script to work!' -ForegroundColor Red
    exit
}

Write-Host 'Searching files, this may take a second...' -ForegroundColor green
$EverythingList = Search-Everything -Global -Filter "path:$Path !-NEW ext:mkv;mp4" | ForEach-Object { Get-Item -LiteralPath $_ }

$num = $EverythingList | Measure-Object
$fileCount = $num.count

$i = 0

foreach ($File in $EverythingList) {
    $Json = mkvmerge -i -F json $File
    $i++;
    $progress = ($i / $fileCount) * 100
    $progress = [Math]::Round($progress)
    Write-Progress -Activity 'MergeMKV' -Status "File $i of $fileCount - Total queue $progress%" -Id 0 -PercentComplete $progress

    $InputFile = $File.FullName
    $FinalName = "$($File.Directory)\$($File.BaseName)$($File.Extension)"
    $OutputFile = "$($File.Directory)\$($File.BaseName)-NEW$($File.Extension)"

    $MergeArgs = @()
    $ContainsSubs = $False

    if ($DelSubs) {
        $MergeArgs += @('-S')
    }

    if ($MKVMergeArgs) {
        $MergeArgs += @("$MKVMergeArgs")
    }

    if (Test-Path "$OutputFile") {
        Remove-Item -LiteralPath "$OutputFile" -Force
    }

    if ($File.Extension -eq '.mp4') {
        if (-not $DelSubs) {
            continue
        }
        else {
            $ContainsSubs = ffprobe.exe "$InputFile" -v error -select_streams s:0 -show_entries stream="codec_type" -of default=noprint_wrappers=1:nokey=1
        }
    }
    else {
        foreach ($Track in $Json | jq '.tracks | keys | .[]') {
            $TrackType = $Json | jq -r .tracks[$Track].type
            if ($Audio -and $TrackType -eq 'audio') {
                $AudioTrack = $Json | jq -r .tracks[$Track].properties.language
                if ($AudioTrack.Contains("$Audio")) {
                    $MergeArgs += @("--default-track-flag $Track`:yes")
                }
                else {
                    $MergeArgs += @("--default-track-flag $Track`:no")
                }
            }
            elseif ($TrackType -eq 'subtitles') {
                $SubTrack = $Json | jq -r .tracks[$Track].properties.track_name
                $SubLang = $Json | jq -r .tracks[$Track].properties.language
                if (-not $DelSubs) {
                    if ($SubLang -eq 'und' -and $Lang) {
                        $MergeArgs += @("--language $Track`:$Lang")
                    }
                    if ($SubTrack.Contains("$Subs")) {
                        $ContainsSubs = $True
                        $MergeArgs += @("--default-track-flag $Track`:yes")
                    }
                    else {
                        $MergeArgs += @("--default-track-flag $Track`:no")
                    }
                }
                else {
                    $ContainsSubs = $True
                }
            }
        }
    }

    if ($ContainsSubs -or $Subs -or $Audio) {
        if ($DelSubs) {
            if ($File.Extension -eq '.mp4') {
                $MP4 = $True
                Write-Host "`nYeeting subs on $($File.BaseName)$($File.Extension) with options: -c:a copy -c:v copy -sn" -ForegroundColor Cyan
                Invoke-Expression "& ffmpeg -i `"$InputFile`" -c:a copy -c:v copy -sn `"$OutputFile`""
            }
            else {
                Write-Host "`nYeeting subs on $($File.BaseName)$($File.Extension) with options: $MergeArgs" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "`nStarting merge on $($File.BaseName)$($File.Extension) with options: $MergeArgs" -ForegroundColor Cyan
        }

        if (-not $MP4) {
            # Write-Host "& mkvmerge.exe $MergeArgs `"$FinalName`" -o `"$OutputFile`""
            Invoke-Expression "& mkvmerge.exe $MergeArgs `"$FinalName`" -o `"$OutputFile`""
        }

        if ($LASTEXITCODE -eq 0) {
            Remove-Item -LiteralPath "$InputFile" -Force
            Rename-Item -LiteralPath "$OutputFile" $FinalName
        }
        else {
            Write-Host "`nmkvmerge encountered an error, deleting $($File.BaseName)-NEW$($File.Extension)" -ForegroundColor Red
            if (Test-Path "$OutputFile") {
                Remove-Item -LiteralPath "$OutputFile" -Force
            }
        }
    }
}
