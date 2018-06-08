[CmdletBinding()]
param(
[Parameter(Mandatory = $true, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
[alias("PSpath", "FullName")]
[ValidateScript( 
    {if (-Not ($_ | Test-Path -PathType Container ) ) { throw "Folder does not exist" }
    return $true })][System.IO.FileInfo]$RootFolder,
[Parameter(Mandatory = $false, Position = 1)]
[datetime]$StartDate = (Get-Date),
[Parameter(Mandatory=$true, Position=2)]
[datetime]$EndDate,
[switch]$Years,
[switch]$Quarters,
[switch]$Months,
[switch]$Weeks,
[switch]$Days,
[switch]$Hours,
[ValidateSet("FullNames", "Abbreviated", "Numeric")][string]$DateFormat
)

process {
for ($RunningDate = $StartDate; $RunningDate -le $EndDate; $Runningdate = $RunningDate.AddDays(1)) {
    if ($Years.IsPresent) { $script:RunningFolder = New-DateFolder -RunningDate $RunningDate -Path $script:RunningFolder -DateInterval "Year" -DateFormat $YearFormat }
    if ($Quarters.IsPresent) {
        switch ($RunningDate.Month){
            {1..3 -contains $_} { $QuarterNumber = $QuarterLabel -f "1" }
            {4..6 -contains $_} { $QuarterNumber = $QuarterLabel -f "2" }
            {7..9 -contains $_} { $QuarterNumber = $QuarterLabel -f "3" }
            {10..12 -contains $_} { $QuarterNumber = $QuarterLabel -f "4" }
            }
            $QuarterFolder = Get-Item -Path $(Join-Path $script:RunningFolder $QuarterNumber) -ErrorAction SilentlyContinue
            if (-not $QuarterFolder) { $script:RunningFolder = New-Item -Path $(Join-Path $script:RunningFolder $QuarterNumber) -ItemType Directory }
            else { $script:RunningFolder = $QuarterFolder }
        }
    if ($Months.IsPresent) { $script:RunningFolder = New-DateFolder -RunningDate $RunningDate -Path $script:RunningFolder -DateInterval "Month" -DateFormat $MonthFormat }
    if ($Weeks.IsPresent) {
        switch ($RunningDate.Day){
            {1..7 -contains $_} { $WeekNumber = $WeekLabel -f "1" }
            {8..15 -contains $_} { $WeekNumber = $WeekLabel -f "2" }
            {16..23 -contains $_} { $WeekNumber = $WeekLabel -f "3" }
            {24..31 -contains $_} { $WeekNumber = $WeekLabel -f "4" }
            }
        $WeekFolder = Get-Item -Path $(Join-Path $script:RunningFolder $WeekNumber) -ErrorAction SilentlyContinue
        if (-not $WeekFolder) { $script:RunningFolder = New-Item -Path $(Join-Path $script:RunningFolder $WeekNumber) -ItemType Directory }
        else { $script:RunningFolder = $WeekFolder }
        }
    if ($Days.IsPresent) { $script:RunningFolder = New-DateFolder -RunningDate $RunningDate -Path $script:RunningFolder -DateInterval "Day" -DateFormat $DayFormat }
    if ($Hours.IsPresent) { 0..24 | ForEach-Object { New-Item -Path $script:RunningFolder -Name $($HourLabel -f $("$($_)u00")) -ItemType Directory | out-Null }}
    #(re)set running values
    $script:RunningFolder = $RootFolder
    }
}

begin {
[datetime]$RunningDate = $StartDate
$script:RunningFolder = $RootFolder
switch ($DateFormat){
    "FullNames"{
        $YearFormat = 'Year_%Y' 
        $MonthFormat = 'Month_%B' 
        $DayFormat = 'Day_%d_%A'
        $WeekLabel = "Week_{0}"
        $QuarterLabel = "Quarter_{0}"
        $HourLabel = "Hour_{0}"
        }
    "Abbreviated"{
        $YearFormat = 'Y_%y'
        $MonthFormat = 'M_%b'
        $DayFormat = '%d_%a'
        $WeekLabel = "W_{0}"
        $QuarterLabel = "Q_{0}"
        $HourLabel = "H_{0}"
        }
    "Numeric"{
        $YearFormat = '%y'
        $MonthFormat = '%m'
        $DayFormat = '%d'
        $WeekLabel = "{0}"
        $QuarterLabel = "{0}"
        $HourLabel = "{0}"
        }
    }

Function New-DateFolder {
param(
$RunningDate,
$Path,
$DateInterval,
$DateFormat
)
$NewFolderName = Get-Date $RunningDate -UFormat $DateFormat
$NewFolder = Get-Item $(Join-Path $Path $NewFolderName) -ErrorAction SilentlyContinue
if (-not ($NewFolder)){ $NewFolder = New-Item -Path $(Join-Path $Path $NewFolderName) -ItemType Directory }
Write-Verbose "creating $($DateInterval) folder $($NewFolderName) under $($Path)"
return $NewFolder
}
}#begin

end {
Write-Verbose "created folders from $($StartDate) to $($EndDate) under $($RootFolder)"
}
