Param(
    [Parameter(Mandatory = $true)] [string] $Path,
    [switch] $DelCSV
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

$ConversionCSV = "$PSScriptRoot\HEVCCheck.csv"

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

$i = 0

Write-Host 'Searching files, this may take a second...' -ForegroundColor green
$EverythingList = Search-Everything -Global -Filter "path:$Path !-NEW ext:mp4;m4v;mkv;webm;wmv;avi;mov;mpeg;flv;divx" | ForEach-Object { Get-Item -LiteralPath $_ }

$num = $EverythingList | Measure-Object
$fileCount = $num.count

foreach ($File in $EverythingList) {
    $i++;
    $progress = ($i / $fileCount) * 100
    $progress = [Math]::Round($progress)
    Write-Host -NoNewline "`rFile $i of $fileCount - Total queue $progress%" -ForegroundColor green
    Write-Progress -Activity 'HEVCCheck' -Status "File $i of $fileCount - Total queue $progress%" -Id 0 -PercentComplete $progress

    if (-not($HashTable.ContainsKey("$($File.BaseName)$($File.Extension)"))) {
        try {
            $Codec = ffprobe.exe $File -v error -select_streams v:0 -show_entries stream="codec_name,height,bit_rate" -of default=noprint_wrappers=1:nokey=1
            if ($Codec[2] -eq 'N/A') {
                $Codec[2] = -1
            }
            $hash = @{
                'Codec'    = $Codec[0]
                'Filename' = "$($File.BaseName)$($File.Extension)"
                'Height'   = $Codec[1]
                'Bitrate'  = $Codec[2]
            }
            $newRow = New-Object PsObject -Property $hash
            Export-Csv $ConversionCSV -InputObject $newrow -Append -Force
        }
        catch {
            exit
        }
    }
}

# This is gross and I need to find a better way of doing this
$csv = Get-Content -Path $ConversionCSV
if ($csv.Contains("`"`"`,`"`"`,`"`"`,`"`"")) {
    If (Test-Path $ConversionCSV) { Remove-Item -LiteralPath "$ConversionCSV" -Force }
    $csv = $csv.Replace("`"`"`,`"`"`,`"`"`,`"`"", '')
    foreach ($Line in $csv) { if (![string]::IsNullOrEmpty($Line)) { $Line >> $ConversionCSV } }
}
