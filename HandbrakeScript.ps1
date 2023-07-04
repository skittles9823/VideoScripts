Param(
    [Parameter(Mandatory = $true)] [string] $Path,
    [switch] $DelCSV,
    $FileSize = '>1KB', # Syntax: [>][<]size[KB|MB|GB]
    $ExtraCompressionProfile = 'null', # SkittlesExtraComp
    # HandBrake options. Full list: https://handbrake.fr/docs/en/latest/cli/command-line-reference.html
    # Use `--preset-import-file .\SkittlesPresets.json` to use the presets I've made instead
    $HandBrakeOptions = '--preset-import-gui', # Import and use presets from HandBrakeGUI
    $EverythingOptions = "path:$Path ext:mp4;m4v;mkv;webm;wmv;avi;mov;mpeg;flv;divx size:$FileSize !-NEW",
    $Logging = 'SingleLog' #Console, PerFile, SingleLog. Console drops all info to console window, perfile creates a new log for each file, singlefile will create a new file for each day.
)

$Version = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
if ($Version -lt 5.1) {
    Write-Host "Powershell version is $Version please upgrade to 5.1 from here: https://www.microsoft.com/en-us/download/details.aspx?id=54616 Quitting" -ForegroundColor Red
    exit
}

Import-Module PSEverything
if (-not(Get-Module PSEverything)) {
    Write-Host 'The Powershell module PSEverything and the Everything service are required for this script to work!' -ForegroundColor Red
    exit
}

$i = 0

$ConversionCSV = "$PSScriptRoot\ConversionsCompleted.csv"

if ($DelCSV) {
    Remove-Item -LiteralPath "$ConversionCSV" -Force
}

If (-not(Test-Path $ConversionCSV)) {
    $headers = 'Codec', 'Height', 'Filename', 'Bitrate'
    $psObject = New-Object psobject
    foreach ($header in $headers) {
        Add-Member -InputObject $psobject -MemberType noteproperty -Name $header -Value ''
    }
    $psObject | Export-Csv $ConversionCSV -NoTypeInformation
    $ConversionCSV = Resolve-Path -Path $ConversionCSV
}

$CompletedTable = Import-Csv -Path $ConversionCSV
$HashTable = @{}
foreach ($file in $CompletedTable) {
    $HashTable[$file.'Filename'] = $file
}

Write-Host 'Searching files, this may take a second...' -ForegroundColor green
$EverythingList = Search-Everything -Global -Filter "$EverythingOptions" | ForEach-Object { Get-Item -LiteralPath $_ }

$num = $EverythingList | Measure-Object
$fileCount = $num.count

foreach ($File in $EverythingList) {
    $i++;
    Switch ($File.Extension) {
        { '.mp4', '.m4v', '.mkv' } {
            $FinalName = "$($File.Directory)\$($File.BaseName)$($File.Extension)"
            $OutputFile = "$($File.Directory)\$($File.BaseName)-NEW$($File.Extension)"
        }
        { '.webm', '.wmv', '.avi', '.mov', '.mpeg', '.flv', '.divx' } {
            $FinalName = "$($File.Directory)\$($File.BaseName).mkv"
            $OutputFile = "$($File.Directory)\$($File.BaseName)-NEW.mkv"
        }
    }
    $progress = ($i / $fileCount) * 100
    $progress = [Math]::Round($progress)
    Write-Progress -Activity 'Handbrake' -Status "File $i of $fileCount - Total queue $progress%" -Id 0 -PercentComplete $progress

    if (-not($HashTable.ContainsKey("$File"))) {
        $Codec = ffprobe.exe $File -v error -select_streams v:0 -show_entries stream="codec_name,height,bit_rate" -of default=noprint_wrappers=1:nokey=1
        if ($Codec[2] -eq 'N/A') {
            $Codec[2] = 0
        }
        if ($Codec[0] -ne 'hevc') {
            # Check that the Output file does not already exist, if it does delete it so the new conversions works as intended.
            if (Test-Path "$OutputFile") {
                Remove-Item "$OutputFile" -Force
            }
            # Change the CPU priorety of $HandBrake to below Normal in 10 seconds so that the conversion has started
            Start-Job -ScriptBlock {
                Start-Sleep -s 10
                $p = Get-Process -Name $HandBrake
                $p.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::BelowNormal
            } | Out-Null
            #region Logging
            if ($Logging -ne 'Console') {
                # Create the Logs directory if it does not exist
                $LogFileDir = "$PSScriptRoot\Logs"
                if (!(Test-Path($LogFileDir))) {
                    New-Item -ItemType Directory -Force -Path $LogFileDir | Out-Null
                }
            }
            If ($Logging -eq 'PerFile') {
                # Build Log file name
                $LogFileName = $File.BaseName -replace '[[\]]', ''
                $LogPath = "$LogFileDir\$LogFileName.txt"
            }
            If ($Logging -eq 'SingleLog') {
                # Build Log file name
                $LogFileName = 'Conversions'
                $LogPath = "$LogFileDir\$LogFileName.txt"
            }
            #endregion

            # Input file
            $InputFile = $File.FullName
            # Write that we are starting the conversion
            $StartingFileSize = $File.Length / 1GB
            Write-Host ' '
            Write-Host "Starting conversion on $InputFile it is $([math]::Round($StartingFileSize,2))GB in size before conversion" -ForegroundColor Cyan
            if ($Logging -eq 'Console') {
                & HandBrakeCLI.exe $HandBrakeOptions -i "$InputFile" -o "$OutputFile"
            }
            else {
                & HandBrakeCLI.exe $HandBrakeOptions -i "$InputFile" -o "$OutputFile" 2>> $LogPath
            }
            Start-Sleep -s 10
            # Check to make sure that the output file actually exists so that if there was a conversion error we don't delete the original
            if (Test-Path -LiteralPath $OutputFile) {
                $EndingFile = Get-Item -LiteralPath $OutputFile | Select-Object Length
                $EndingFileSize = $EndingFile.Length / 1GB
                # Use the ExtraCompression preset if the default wasn't good enough
                if ($EndingFileSize -ge $StartingFileSize) {
                    if ($ExtraCompressionProfile -ne 'null') {
                        Write-Host "The file was larger than it was before so we go agane ($([math]::Round($StartingFileSize,4))GB/$([math]::Round($EndingFileSize,4))GB)" -ForegroundColor Red
                        if ($Logging -eq 'Console') {
                            & HandBrakeCLI.exe $HandBrakeOptions -Z $ExtraCompressionProfile -i "$InputFile" -o "$OutputFile"
                        }
                        else {
                            & HandBrakeCLI.exe $HandBrakeOptions -Z $ExtraCompressionProfile -i "$InputFile" -o "$OutputFile" 2>> $LogPath
                        }
                        $EndingFile = Get-Item $OutputFile | Select-Object Length
                        $EndingFileSize = $EndingFile.Length / 1GB
                        # Still have to have this or else we just waste space
                        if ($EndingFileSize -ge $StartingFileSize) {
                            Write-Host "The file was Still larger than it was before so it was not converted ($([math]::Round($StartingFileSize,4))GB/$([math]::Round($EndingFileSize,4))GB)" -ForegroundColor Red
                            Remove-Item -LiteralPath "$OutputFile" -Force
                        }
                        else {
                            Remove-Item -LiteralPath $InputFile -Force
                            Rename-Item -LiteralPath "$OutputFile" $FinalName
                            Write-Host "Finished Xtreme encode of $InputFile" -ForegroundColor Green
                            Write-Host "New ending file size is $([math]::Round($EndingFileSize,4))GB. Space saved is $([math]::Round($StartingFileSize-$EndingFileSize,4))GB" -ForegroundColor Green
                            $hash = @{
                                'Codec'    = $Codec[0]
                                'Height'   = $Codec[1]
                                'Filename' = $FinalName
                                'Bitrate'  = $Codec[2]
                            }
                            $newRow = New-Object PsObject -Property $hash
                            Export-Csv $ConversionCSV -InputObject $newrow -Append -Force
                        }
                    }
                    else {
                        Write-Host "The file was larger than it was before so it was not converted ($([math]::Round($StartingFileSize,4))GB/$([math]::Round($EndingFileSize,4))GB)" -ForegroundColor Red
                        Remove-Item -LiteralPath "$OutputFile" -Force
                    }
                }
                else {
                    Remove-Item -LiteralPath $InputFile -Force
                    Rename-Item -LiteralPath "$OutputFile" $FinalName
                    Write-Host "Finished converting $InputFile" -ForegroundColor Green
                    Write-Host "Ending file size is $([math]::Round($EndingFileSize,4))GB. Space saved is $([math]::Round($StartingFileSize-$EndingFileSize,4))GB" -ForegroundColor Green
                    $hash = @{
                        'Codec'    = $Codec[0]
                        'Height'   = $Codec[1]
                        'Filename' = $FinalName
                        'Bitrate'  = $Codec[2]
                    }
                    $newRow = New-Object PsObject -Property $hash
                    Export-Csv $ConversionCSV -InputObject $newrow -Append -Force
                }
            }
        }
        else {
            Write-Host ' '
            Write-Host "$File already HEVC encoded, skipping!" -ForegroundColor DarkGreen
            $hash = @{
                'Codec'    = $Codec[0]
                'Height'   = $Codec[1]
                'Filename' = $File
                'Bitrate'  = $Codec[2]
            }
            $newRow = New-Object PsObject -Property $hash
            Export-Csv $ConversionCSV -InputObject $newrow -Append -Force
        }
    }
    # If file exists in Conversions Completed Spreadsheet write that we are skipping the file because it was already converted
    elseif ($HashTable.ContainsKey("$File")) {
        Write-Host ' '
        Write-Host "Skipping $($File.BaseName)$($File.Extension) because it was already converted." -ForegroundColor DarkGreen
    }
}

# This is gross and I need to find a better way of doing this
$csv = Get-Content -Path $ConversionCSV
if ($csv.Contains("`"`"`,`"`"`,`"`"`,`"`"")) {
    If (Test-Path $ConversionCSV) { Remove-Item -LiteralPath "$ConversionCSV" -Force }
    $csv = $csv.Replace("`"`"`,`"`"`,`"`"`,`"`"", '')
    foreach ($Line in $csv) { if (![string]::IsNullOrEmpty($Line)) { $Line >> $ConversionCSV } }
}
