Param(
    [Parameter(Mandatory = $true)] [string] $Path
)

Import-Module PSEverything
if (-not(Get-Module PSEverything)) {
    Write-Host 'The Powershell module PSEverything and the Everything service are required for this script to work!' -ForegroundColor Red
    exit
}

$MKVCheckCSV = "$PSScriptRoot\MKVCheck.csv"

If (Test-Path $MKVCheckCSV) { Remove-Item -LiteralPath "$MKVCheckCSV" -Force }

If (-not(Test-Path $MKVCheckCSV)) {
    $headers = 'Filename', 'Track ID', 'Name', 'Language', 'Type'
    $PsObject = New-Object PsObject
    foreach ($header in $headers) {
        Add-Member -InputObject $PsObject -MemberType noteproperty -Name $header -Value ''
    }
    $PsObject | Export-Csv $MKVCheckCSV -NoTypeInformation
    $MKVCheckCSV = Resolve-Path -Path $MKVCheckCSV
}

$CompletedTable = Import-Csv -Path $MKVCheckCSV
$HashTable = @{}
foreach ($file in $CompletedTable) {
    $HashTable[$file.'Filename'] = $file
}

Write-Host 'Searching files, this may take a second...' -ForegroundColor green
$EverythingList = Search-Everything -Global -Filter "path:$Path !-NEW ext:mkv" | ForEach-Object { Get-Item -LiteralPath $_ }

$num = $EverythingList | Measure-Object
$fileCount = $num.count
$i = 0

foreach ($File in $EverythingList) {
    $Json = mkvmerge -i -F json $File
    $i++;
    $progress = ($i / $fileCount) * 100
    $progress = [Math]::Round($progress)
    Write-Progress -Activity 'MKVCheck' -Status "File $i of $fileCount - Total queue $progress%" -Id 0 -PercentComplete $progress
    if (-not($HashTable.ContainsKey("$($File.BaseName)$($File.Extension)"))) {
        foreach ($Track in $Json | jq -r '.tracks | keys | .[]') {
            if (($Json | jq -r .tracks[$Track].type) -ne 'video') {
                $TrackName = $Json | jq -r .tracks[$Track].properties.track_name
                $TrackLang = $Json | jq -r .tracks[$Track].properties.language
                $TrackType = $Json | jq -r .tracks[$Track].type
                $hash = @{
                    'Filename' = "$($File.BaseName)$($File.Extension)"
                    'Track ID' = $Track
                    'Name'     = $TrackName
                    'Language' = $TrackLang
                    'Type'     = $TrackType
                }
                $newRow = New-Object PsObject -Property $hash
                Export-Csv $MKVCheckCSV -InputObject $newrow -Append -Force
            }
        }
    }
}

# This is gross and I need to find a better way of doing this
$csv = Get-Content -Path $MKVCheckCSV
if ($csv.Contains("`"`"`,`"`"`,`"`"`,`"`"`,`"`"")) {
    If (Test-Path $MKVCheckCSV) { Remove-Item -LiteralPath "$MKVCheckCSV" -Force }
    $csv = $csv.Replace("`"`"`,`"`"`,`"`"`,`"`"`,`"`"", '')
    foreach ($Line in $csv) { if (![string]::IsNullOrEmpty($Line)) { $Line >> $MKVCheckCSV } }
}

Import-Csv -Path $MKVCheckCSV
