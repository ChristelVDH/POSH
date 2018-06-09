[CmdletBinding()]
param(
[Parameter(Mandatory = $true, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
[ValidateScript({ $_ | ForEach-Object {(Get-Item $_).PSIsContainer}})]
[alias("PSpath", "FullName")][string[]]$RootFolders,
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
[switch]$Minutes,
[Parameter(Mandatory=$true)]
[ValidateSet("FullNames", "Abbreviated", "Numeric")][string]$DateFormat
)

process {
foreach ($RootFolder in $RootFolders){
    [datetime]$RunningDate = $StartDate
    $script:RunningFolder = $RootFolder
    #total number of days = difference days + startday + endday
    [int]$AlmanakTimeSpan = (New-TimeSpan -Start $StartDate -End $EndDate).Days + 2
    [int]$NumberOfDaysProcessed = 0
    for ($RunningDate = $StartDate; $RunningDate -le $EndDate; $Runningdate = $RunningDate.AddDays(1)) {
        Write-Progress -Activity "New-Almanak" -Status "Creating almanak folder tree under $($RootFolder)" -PercentComplete ($NumberOfDaysProcessed++ / $AlmanakTimeSpan * 100)
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
        #minutes depend on presence of hours because of granularity per day of for loop
        if ($Hours.IsPresent) {
            $script:HourFolder = ""
            0..23 | ForEach-Object {
                $script:HourFolder = Join-Path $script:RunningFolder $($HourLabel -f $("$($_)u00"))
                if (-not (Get-Item $script:HourFolder -ErrorAction SilentlyContinue )) { $script:HourFolder = New-Item -Path $script:HourFolder -ItemType Directory -ErrorAction SilentlyContinue }
                if ($Minutes.IsPresent) {
                    0..59 | ForEach-Object {
                        $MinuteFolder = Join-Path $script:HourFolder $($MinuteLabel -f $_).PadLeft(2,"0")
                        if (-not ( Get-Item -Path $MinuteFolder -ErrorAction SilentlyContinue )){ New-Item -Path $MinuteFolder -ItemType Directory -ErrorAction SilentlyContinue | out-Null }
                        }
                    }
                }
            }
        #(re)set running values
        $script:RunningFolder = $RootFolder
        }
    }
}

begin {

switch ($DateFormat){
    "FullNames"{
        $YearFormat = 'Year_%Y' 
        $MonthFormat = 'Month_%B' 
        $DayFormat = 'Day_%d_%A'
        $WeekLabel = "Week_{0}"
        $QuarterLabel = "Quarter_{0}"
        $HourLabel = "Hour_{0}"
        $MinuteLabel = "Minute_{0}"
        }
    "Abbreviated"{
        $YearFormat = 'Y_%y'
        $MonthFormat = 'M_%b'
        $DayFormat = '%d_%a'
        $WeekLabel = "W_{0}"
        $QuarterLabel = "Q_{0}"
        $HourLabel = "H_{0}"
        $MinuteLabel = "Min_{0}"
        }
    "Numeric"{
        $YearFormat = '%y'
        $MonthFormat = '%m'
        $DayFormat = '%d'
        $WeekLabel = "{0}"
        $QuarterLabel = "{0}"
        $HourLabel = "{0}"
        $MinuteLabel = "{0}"
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
foreach ($RootFolder in $RootFolders){ Write-Verbose "created folders from $($StartDate) to $($EndDate) under $($RootFolder)" }
}
