Param(
    $BasePath = $args[0],
    $FileSize = ">1KB", # Syntax: [>][<]size[KB|MB|GB]
    $EverythingOptions = "path:$BasePath ext:mp4;m4v;mkv;webm;wmv;avi;mov;mpeg;flv;divx size:$FileSize !-NEW"
    # path:$BasePath ext:mp4;m4v;mkv;webm;wmv;avi;mov;mpeg;flv size:$FileSize !-NEW
)

$Version = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
if ($Version -lt 5.1) {
    Write-Host "Powershell version is $Version please upgrade to 5.1 from here: https://www.microsoft.com/en-us/download/details.aspx?id=54616 Quitting" -ForegroundColor Red
    exit
}

Import-Module PSEverything
if (-not(Get-Module PSEverything)) {
    Write-Host "The Powershell module PSEverything and the Everything service are required for this script to work!" -ForegroundColor Red
    exit
}

if (!$WorkingDir) {
    $WorkingDir = (Resolve-Path .\).Path
}

$ConversionCSV = "$WorkingDir\HEVCCheck.csv"
If (-not(Test-Path $ConversionCSV)) {
    $headers = "Height", "Filename", "Bitrate"
    $psObject = New-Object psobject
    foreach ($header in $headers) {
        Add-Member -InputObject $psobject -MemberType noteproperty -Name $header -Value ""
    }
    $psObject | Export-Csv $ConversionCSV -NoTypeInformation
    $ConversionCSV = Resolve-Path -Path $ConversionCSV
}

$CompletedTable = Import-Csv -Path $ConversionCSV
$HashTable = @{}
foreach ($file in $CompletedTable) {
    $HashTable[$file."Filename"] = $file
}

$i = 0
$EverythingList = Search-Everything -Global -Filter "$EverythingOptions"
Write-Host "Escaping bad characters, this may take a second..."  -foregroundcolor green
$EverythingList = $EverythingList.Replace('[', '`[').Replace(']', '`]') | Get-Item | Sort-Object Length -Descending

$num = $EverythingList | Measure-Object
$fileCount = $num.count

foreach ($File in $EverythingList) {
    $i++;
    $progress = ($i / $fileCount) * 100
    $progress = [Math]::Round($progress, 2)
    Write-Host -NoNewLine "`rFile $i of $fileCount - Total queue $progress%" -foregroundcolor green
    if (-not($HashTable.ContainsKey("$File"))) {
        $Codec = ffprobe.exe $File -v error -select_streams v:0 -show_entries stream="codec_name,height,bit_rate" -of default=noprint_wrappers=1:nokey=1
        if ($Codec[2] -eq "N/A") {
            $Codec[2] = 0
        }
        if ($Codec[0] -ne "hevc") {
            $hash = @{
                "Height"   = $Codec[1]
                "Filename" = $File
                "Bitrate"  = $Codec[2]
            }
            $newRow = New-Object PsObject -Property $hash
            Export-Csv $ConversionCSV -inputobject $newrow -append -Force
        }
    }
}
